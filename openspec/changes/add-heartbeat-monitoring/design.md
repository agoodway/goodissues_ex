## Context

FruitFly is adding proactive monitoring alongside its existing issue tracking. The `add-uptime-checks` change introduces active HTTP monitoring with an `FF.Monitoring` context, self-rescheduling Oban workers, and an incident lifecycle that auto-creates/reopens/archives issues via a system bot user. Heartbeat monitoring builds on that same infrastructure but inverts the direction: instead of FruitFly reaching out, external jobs ping FruitFly to prove they're running.

This change depends on `add-uptime-checks` landing first, or being reconciled into this change before implementation starts, because it reuses that monitoring context, incident lifecycle, and bot-user flow.

It also depends on `harden-check-scheduling` landing first, or its invariants being folded into the heartbeat implementation plan, because heartbeat deadlines are another self-rescheduling monitoring chain and should not repeat the failure modes already identified for checks.

The key integration points are:
- `FF.Monitoring` context (extended with heartbeat functions)
- Incident lifecycle rules (create, reopen, archive, and issue linking) — reused semantically, but heartbeat implementation needs a heartbeat-specific wrapper or generalized lifecycle path because the current code is check-specific
- Bot user (`FF.Accounts.get_or_create_bot_user!/1`) — reused as-is
- Hardened monitoring scheduling/recovery pattern (`try/after` style reschedule guarantees, stale-job invalidation, and periodic orphan/stuck recovery) — reused for deadline detection

## Goals / Non-Goals

**Goals:**
- Users can configure heartbeat monitors scoped to projects with interval + grace period scheduling
- Each heartbeat has a unique 42-char token embedded in its ping URL for zero-auth pings
- Jobs can signal success (`/ping`), start (`/ping/start`), or failure (`/ping/fail`) with optional JSON payloads
- Duration is computed automatically from start→ping pairs
- Per-heartbeat Oban deadline workers detect missed pings and trigger incident lifecycle
- Alert rules (jsonb) evaluate payload fields and fire incidents even when pings arrive on time
- Management API for heartbeat CRUD and ping history, scoped under projects
- Ping endpoints authenticate via token in URL — no Bearer token required

**Non-Goals:**
- Cron expression scheduling (intervals only for this change)
- Public status pages or uptime percentage calculations
- Webhook/email/Slack notifications beyond issue creation
- Ping result pruning or retention policies
- Rate limiting on ping endpoints (acceptable at current scale)
- Multi-region ping reception

## Decisions

### 1. Heartbeat as a Separate Resource (not a Check variant)

**Decision**: Create `Heartbeat` and `HeartbeatPing` schemas alongside `Check` and `CheckResult`, not as a polymorphic "check type."

**Rationale**: Heartbeats and checks have fundamentally different lifecycles. Checks are active (FruitFly initiates), heartbeats are passive (external jobs initiate). Their fields diverge significantly — heartbeats need `ping_token`, `grace_seconds`, `alert_rules`, `started_at`; checks need `url`, `method`, `expected_status`, `keyword`. Forcing polymorphism would mean nullable fields and conditional logic everywhere.

**Alternative considered**: Single `Monitor` table with a `type` discriminator — rejected because it couples two domains that happen to share an incident lifecycle but differ in everything else.

### 2. 42-Character Random Token for Ping URLs

**Decision**: Generate a cryptographically random 42-character URL-safe token per heartbeat. The token IS the authentication.

**Rationale**: Cronping and healthchecks.io both use this pattern successfully. The token provides 252 bits of entropy (42 base64url chars), making brute-force infeasible. This eliminates the need for API key auth on ping endpoints, which is critical because ping calls are embedded in cron scripts where managing Bearer tokens adds friction.

**Generation**: `:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false) |> binary_part(0, 42)`

### 3. Per-Heartbeat Deadline Worker (Hardened Self-Rescheduling)

**Decision**: Each heartbeat gets its own Oban job that fires at a persisted `next_due_at`, but it must follow the hardened scheduling invariants from `harden-check-scheduling` rather than the original best-effort check chain.

**Rationale**: Per-heartbeat scheduling gives precise timing — a heartbeat with a 5-minute interval triggers exactly when overdue, not on a polling cycle. But heartbeat deadlines are still monitoring infrastructure, so they need the same resilience guarantees as hardened check scheduling: the chain must not silently die if work raises, and periodic recovery must exist between deploys.

**Scheduling anchor**: Persist `next_due_at` on the heartbeat so rescheduling after `/ping/fail` or a missed deadline does not fall back to a stale success ping timestamp.

**Lifecycle**:
- Creating a heartbeat → sets `next_due_at = now + interval + grace` and schedules first deadline (unless paused)
- Receiving a logical success ping → cancels current deadline job, sets `next_due_at = now + interval + grace`, schedules new deadline
- Receiving `/ping/fail` → increments failures, sets `next_due_at = now + interval + grace`, cancels current deadline job, schedules new deadline
- Deadline fires (no ping arrived) → increment `consecutive_failures`, evaluate threshold, trigger incident if met, advance `next_due_at` from the prior due time, and reschedule next deadline
- Pausing → cancel or supersede the current pending deadline, and paused deadlines do not mutate failure or incident state
- Deleting → cancel pending deadline jobs

**Hardening rules**:
- `perform/1` is responsible for preserving the chain even when the work body raises (for example via `try/after` or an equivalent shared scheduler primitive)
- The deadline worker's unique states exclude `:executing` so self-rescheduling cannot collide with the in-flight job
- Deadline jobs carry their computed `scheduled_for` due time and re-read `heartbeat.next_due_at` before mutating state; if the stored heartbeat state implies a different current due time, the job is stale and must no-op
- The same periodic orphan/stuck-job recovery model used for hardened check scheduling must also recover heartbeat deadline chains between deploys, using the same stuck threshold of `attempted_at < now - (5 × interval_seconds)`

**Alternative considered**: Global polling worker that sweeps all heartbeats every 30s — rejected for consistency with `CheckRunner` pattern and precision.

### 4. Ping Endpoint Design

**Decision**: Nest ping endpoints under the project path: `POST /api/v1/projects/:project_id/heartbeats/:heartbeat_token/ping[/start|/fail]`

**Rationale**: Keeps routing consistent with the rest of the API while preserving resource-specific param names. The token in the URL authenticates the request. Project ID in the path keeps project scoping explicit and lets the lookup validate `project_id` and `heartbeat_token` together even though tokens remain globally unique.

**Endpoints**:
- `POST /api/v1/projects/:project_id/heartbeats/:heartbeat_token/ping` — success signal
- `POST /api/v1/projects/:project_id/heartbeats/:heartbeat_token/ping/start` — job started
- `POST /api/v1/projects/:project_id/heartbeats/:heartbeat_token/ping/fail` — immediate failure

**Body** (optional): JSON payload with arbitrary fields on `/ping` and `/ping/start`. On `/ping/fail`, `exit_code` is a reserved top-level field recorded separately, and any remaining JSON fields are stored in `heartbeat_pings.payload`.

### 5. Context-Aware Alert Rules

**Decision**: Store alert rules as a jsonb array on the heartbeat. Evaluate rules against the ping payload on every successful ping.

**Schema**:
```json
[
  {"field": "rows_processed", "op": "lt", "value": 100},
  {"field": "duration_ms", "op": "gt", "value": 300000},
  {"field": "error_count", "op": "gt", "value": 0}
]
```

**Supported operators**: `eq`, `neq`, `gt`, `gte`, `lt`, `lte`

**Value semantics**: Rules target only flat top-level payload fields plus virtual `duration_ms`. Rule values are JSON scalars (`string`, `number`, `boolean`, `null`). Nested field paths are out of scope for this change.

**Evaluation**: When a `/ping` arrives, evaluate alert rules against payload fields when present plus virtual `duration_ms` when available. If ANY rule matches, treat this ping as a failure (increment `consecutive_failures`, evaluate incident threshold, and create/reopen an incident if the threshold is reached). The ping is still recorded as received, but the heartbeat may transition to `:down` based on rules.

**Rationale**: This matches Cronping's "context-aware monitoring" — detecting jobs that complete but produce bad results. Keeping rules as data (not code) makes them user-configurable via the management API.

### 6. Duration Tracking

**Decision**: Compute `duration_ms` on the ping record when a `/start` preceded the `/ping`. Store `started_at` on the heartbeat to track pending starts, but clear stale `started_at` values on terminal failure transitions.

**Flow**:
1. `/start` received → set `heartbeat.started_at = now()`, record ping with kind `:start`
2. `/ping` received → if `started_at` is set, compute `duration_ms = now - started_at`, clear `started_at`
3. Duration is a field on `HeartbeatPing`, alertable via `alert_rules` like any other payload field
4. `/ping/fail` or a missed deadline clears `started_at` so later successes do not inherit stale start timestamps from a dead run

**Precedence rule**: Server-computed `duration_ms` overrides any client-supplied `duration_ms` during alert evaluation.

**No dedicated duration threshold column** — users who want duration alerts add a rule: `{"field": "duration_ms", "op": "gt", "value": 300000}`.

### 7. Token Visibility and Secret Handling

**Decision**: Treat `ping_token` and full ping URLs as write-capable secrets.

**Read/write response contract**:
- Create flows return the full ping URL so the caller can provision the external job
- All later management responses (show, update, list/history parent resources) redact token-bearing fields and return only masked token metadata
- Regenerating or re-revealing a token is out of scope for this change

**Rationale**: The token is the only credential required to mutate heartbeat state through the public ping endpoints. Exposing it on read-only management responses would effectively turn `heartbeats:read` into a write-equivalent permission.

### 8. Serialized Heartbeat State Transitions

**Decision**: Ping reception and deadline execution both operate inside a single locked transaction over the heartbeat row.

**Rationale**: `/ping`, `/ping/fail`, `/ping/start`, and deadline jobs all mutate the same fields (`consecutive_failures`, `status`, `current_issue_id`, `started_at`, and scheduling state). Serializing those transitions avoids double-increments, stale incident decisions, and recovery/archive races.

**Implementation shape**: Use `Ecto.Multi` and row locking (`FOR UPDATE` or equivalent) so ping recording, heartbeat mutation, and incident lifecycle actions commit as one state transition.

### 9. Heartbeat-Specific Incident Lifecycle Wrapper

**Decision**: Implement heartbeat incident handling through a heartbeat-specific lifecycle wrapper in `FF.Monitoring` rather than claiming the current `IncidentLifecycle` module can be reused unchanged.

**Rationale**: The existing lifecycle code is check-specific: it expects `Check` and `CheckResult` inputs, builds check-shaped issue titles/descriptions, and links incidents back through `check_results.issue_id`. Heartbeats need the same incident rules, but with heartbeat/heartbeat_ping inputs and heartbeat-specific linkage.

**Wrapper responsibilities**:
- Create or reopen incidents when heartbeat failures cross threshold
- Archive incidents when a heartbeat recovers
- Populate `heartbeat_pings.issue_id` when the triggering signal came from a recorded ping
- Preserve the same reopen-window and bot-user semantics as uptime checks

### 10. Deadline Worker and App Integration

**Decision**: Use a dedicated `:heartbeats` queue separate from the `:checks` queue, and wire startup recovery plus a heartbeat-specific periodic recovery worker through the existing app-level Oban and application boot integration points.

**Rationale**: Deadline jobs are time-sensitive (they determine when alerts fire). Isolating them from check execution prevents a flood of slow HTTP checks from delaying deadline evaluation. A heartbeat-specific periodic recovery worker avoids ambiguity with the check-centric reaper contract while still reusing the same recovery invariants. Default concurrency: 10.

## Risks / Trade-offs

- **[Clock skew in deadline calculation]** → Oban scheduled_at and persisted `next_due_at` use DB-backed timestamps, so all timing is consistent within the system. Acceptable for the precision level needed (seconds, not milliseconds).
- **[Token in URL logged by proxies]** → Ping tokens may appear in access logs. Mitigated by the fact that tokens do not grant read access to account data, but they are still write-capable heartbeat credentials that can mutate heartbeat state and influence incident lifecycle. Acceptable risk at current scale.
- **[Unbounded heartbeat_pings table]** → Same trade-off as check_results — no pruning in this change. Ship and add retention later.
- **[Alert rule complexity]** → Supporting only flat field access (no nested paths). If users need `payload.stats.rows`, they'll need to flatten before sending. Acceptable for MVP.
- **[Race condition on /start + /ping]** → If start and ping arrive simultaneously, duration may be zero or negative. Mitigated by using DB timestamps and accepting minor imprecision.
- **[Deadline job after ping race]** → A ping could arrive just as the deadline job fires. Mitigated by running both paths inside locked transactions and by validating the job's `scheduled_for` against the heartbeat's current due time before mutating state.
