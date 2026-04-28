## Context

FruitFly is adding proactive monitoring alongside its existing issue tracking. The `add-uptime-checks` change introduces active HTTP monitoring with an `FF.Monitoring` context, self-rescheduling Oban workers, and an incident lifecycle that auto-creates/reopens/archives issues via a system bot user. Heartbeat monitoring builds on that same infrastructure but inverts the direction: instead of FruitFly reaching out, external jobs ping FruitFly to prove they're running.

This change depends on `add-uptime-checks` landing first, or being reconciled into this change before implementation starts, because it reuses that monitoring context, incident lifecycle, and bot-user flow.

The key integration points are:
- `FF.Monitoring` context (extended with heartbeat functions)
- Incident lifecycle (`create_or_reopen_incident/3`, `archive_incident/2`) — reused as-is
- Bot user (`FF.Accounts.get_or_create_bot_user!/1`) — reused as-is
- Oban self-rescheduling pattern — replicated for deadline detection

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

### 3. Per-Heartbeat Deadline Worker (Self-Rescheduling)

**Decision**: Each heartbeat gets its own Oban job that fires at `last_ping_at + interval_seconds + grace_seconds`. Same self-rescheduling pattern as the uptime check runner.

**Rationale**: Consistent with the check execution pattern already in the codebase. Per-heartbeat scheduling gives precise timing — a heartbeat with a 5-minute interval triggers exactly when overdue, not on a polling cycle. The Oban `unique` constraint on `heartbeat_id` prevents duplicate chains.

**Lifecycle**:
- Creating a heartbeat → schedules first deadline at `now + interval + grace` (unless paused)
- Receiving a ping → cancels current deadline job, schedules new one at `now + interval + grace`
- Deadline fires (no ping arrived) → increment `consecutive_failures`, evaluate threshold, trigger incident if met, reschedule next deadline
- Pausing → don't reschedule after current deadline
- Deleting → cancel pending deadline jobs

**Alternative considered**: Global polling worker that sweeps all heartbeats every 30s — rejected for consistency with `CheckRunner` pattern and precision.

### 4. Ping Endpoint Design

**Decision**: Nest ping endpoints under the project path: `POST /api/v1/projects/:project_id/heartbeats/:token/ping[/start|/fail]`

**Rationale**: Keeps routing consistent with the rest of the API. The token in the URL authenticates the request. Project ID in the path keeps project scoping explicit and lets the lookup validate `project_id` and `token` together.

**Endpoints**:
- `POST /api/v1/projects/:project_id/heartbeats/:token/ping` — success signal
- `POST /api/v1/projects/:project_id/heartbeats/:token/ping/start` — job started
- `POST /api/v1/projects/:project_id/heartbeats/:token/ping/fail` — immediate failure

**Body** (optional): JSON payload with arbitrary fields + optional `exit_code` integer.

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

**Evaluation**: When a `/ping` arrives with a JSON body, iterate alert rules. If ANY rule matches, treat this ping as a failure (increment `consecutive_failures`, evaluate incident threshold). The ping is still recorded as received, but the heartbeat may transition to `:down` based on rules.

**Rationale**: This matches Cronping's "context-aware monitoring" — detecting jobs that complete but produce bad results. Keeping rules as data (not code) makes them user-configurable via the management API.

### 6. Duration Tracking

**Decision**: Compute `duration_ms` on the ping record when a `/start` preceded the `/ping`. Store `started_at` on the heartbeat to track pending starts.

**Flow**:
1. `/start` received → set `heartbeat.started_at = now()`, record ping with kind `:start`
2. `/ping` received → if `started_at` is set, compute `duration_ms = now - started_at`, clear `started_at`
3. Duration is a field on `HeartbeatPing`, alertable via `alert_rules` like any other payload field

**No dedicated duration threshold column** — users who want duration alerts add a rule: `{"field": "duration_ms", "op": "gt", "value": 300000}`.

### 7. Oban Queue Configuration

**Decision**: Use a dedicated `:heartbeats` queue separate from the `:checks` queue.

**Rationale**: Deadline jobs are time-sensitive (they determine when alerts fire). Isolating them from check execution prevents a flood of slow HTTP checks from delaying deadline evaluation. Default concurrency: 10.

## Risks / Trade-offs

- **[Clock skew in deadline calculation]** → Oban scheduled_at uses DB time, so all timing is consistent within the system. Acceptable for the precision level needed (seconds, not milliseconds).
- **[Token in URL logged by proxies]** → Ping tokens may appear in access logs. Mitigated by the fact that tokens only grant "send a ping" capability, not read access to any data. Acceptable risk.
- **[Unbounded heartbeat_pings table]** → Same trade-off as check_results — no pruning in this change. Ship and add retention later.
- **[Alert rule complexity]** → Supporting only flat field access (no nested paths). If users need `payload.stats.rows`, they'll need to flatten before sending. Acceptable for MVP.
- **[Race condition on /start + /ping]** → If start and ping arrive simultaneously, duration may be zero or negative. Mitigated by using DB timestamps and accepting minor imprecision.
- **[Deadline job after ping race]** → A ping could arrive just as the deadline job fires. Mitigated by re-reading `last_ping_at` in the deadline job before marking as failed — if a ping arrived since scheduling, skip the failure.
