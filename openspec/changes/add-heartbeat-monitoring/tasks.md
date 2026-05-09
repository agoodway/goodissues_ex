## 0. Dependencies

- [x] 0.1 Reconcile with or wait for `add-uptime-checks` so `GI.Monitoring`, the incident lifecycle, and bot-user support exist before heartbeat implementation begins
- [x] 0.2 Reconcile with or wait for `harden-check-scheduling` so heartbeat deadline workers inherit the hardened monitoring-job invariants (guaranteed reschedule, stale-job invalidation, and periodic orphan/stuck recovery)

## 1. Database & Schemas

- [x] 1.1 Create migration for heartbeats table (id, name, ping_token varchar(42) unique, interval_seconds, grace_seconds, failure_threshold default 1, reopen_window_hours default 24, status default :unknown, consecutive_failures default 0, last_ping_at, next_due_at, started_at, current_issue_id FK, project_id FK, created_by_id FK, alert_rules jsonb default [], paused boolean default false, timestamps)
- [x] 1.2 Create migration for heartbeat_pings table (id, kind enum(:ping, :start, :fail), exit_code integer nullable, payload jsonb nullable, duration_ms integer nullable, pinged_at utc_datetime_usec, heartbeat_id FK on_delete: :delete_all, issue_id FK nullable)
- [x] 1.3 Create GI.Monitoring.Heartbeat Ecto schema with validations (name required, status enum aligned with monitoring conventions and defaulting to `:unknown`, interval_seconds 30..86400, grace_seconds 0..86400, failure_threshold default 1 with `>= 1`, reopen_window_hours default 24 with `>= 1`, consecutive_failures default 0, alert_rules validated structure, persisted `next_due_at` scheduling anchor)
- [x] 1.4 Create GI.Monitoring.HeartbeatPing Ecto schema (read-only, no update changeset)
- [x] 1.5 Add ping_token generation using :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false) |> binary_part(0, 42) with retry on unique constraint violation

## 2. Monitoring Context — Heartbeat CRUD

- [x] 2.1 Add `create_heartbeat/3` following the existing Monitoring pattern: `%Account{}`, `%User{}`, attrs — generates token, inserts heartbeat, enqueues first deadline job unless paused
- [x] 2.2 Add `list_heartbeats/3` following the existing Monitoring pattern: `%Account{}`, project_id, pagination params — paginated and ordered consistently with existing monitor listings
- [x] 2.3 Add `get_heartbeat/3` and `get_heartbeat!/3` scoped to account + project for controller-facing 404 handling and internal bang lookups
- [x] 2.4 Add non-bang token lookup for ping endpoints (project_id, heartbeat_token) that returns not found cleanly so controllers can map unknown token/project mismatches to 404
- [x] 2.5 Add `update_heartbeat/2` — updates fields, cancels or supersedes the pending deadline on pause (`paused: false -> true`), reschedules deadline if interval/grace changed, and enqueues deadline on resume from paused
- [x] 2.6 Add `delete_heartbeat/1` — deletes heartbeat and cancels pending Oban jobs without auto-archiving any existing linked incident issue
- [x] 2.7 Add tests for all heartbeat CRUD functions

## 3. Ping Reception

- [x] 3.1 Add `receive_ping/3` (heartbeat, kind, attrs) as a locked transaction that records `HeartbeatPing`, mutates heartbeat state, and performs incident lifecycle actions atomically
- [x] 3.2 Implement success ping logic: update last_ping_at, compute duration_ms if started_at set, clear started_at, set `next_due_at = now + interval + grace`, cancel current deadline, schedule new deadline from `next_due_at`, treat alert-rule matches as immediate logical failures that increment `consecutive_failures` and evaluate `failure_threshold`, and only set `status: :up` plus reset consecutive_failures on logical success (including the first success from `:unknown`)
- [x] 3.3 Implement start ping logic: set heartbeat.started_at, record ping with kind :start, and persist any supplied JSON payload
- [x] 3.4 Implement fail ping logic: increment consecutive_failures, clear started_at, set `next_due_at = now + interval + grace`, cancel the current deadline, record ping with kind :fail including payload plus separately persisted reserved `exit_code`, reschedule the next deadline from `next_due_at`, and evaluate incident threshold immediately
- [x] 3.5 Implement recovery logic: when success ping arrives and status is :down and alert rules pass, archive incident, clear current_issue_id, reset consecutive_failures, set status :up
- [x] 3.6 Add list_heartbeat_pings/2 (heartbeat, pagination params) — paginated reverse chronological
- [x] 3.7 Create `GI.Monitoring.HeartbeatIncidentLifecycle` (or equivalent generalized lifecycle path) that applies incident create/reopen/archive rules to heartbeat inputs and populates `HeartbeatPing.issue_id` when a recorded ping triggered the transition
- [x] 3.8 Add tests for ping reception (all three kinds), duration computation, rule-triggered incident creation, `HeartbeatPing.issue_id` linkage for newly created/reopened incidents and already-open incidents, stale started_at cleanup, recovery, and ping-vs-deadline concurrency races

## 4. Alert Rule Evaluation

- [x] 4.1 Create GI.Monitoring.AlertRuleEvaluator module with evaluate/2 (rules, payload_with_duration) → :pass | :fail
- [x] 4.2 Implement operator evaluation for flat top-level payload fields and `duration_ms`: eq, neq, gt, gte, lt, lte with explicit JSON-scalar comparison semantics (skip rule on missing field, unsupported type, or type mismatch)
- [x] 4.3 Implement ANY-match semantics: if any rule fires, return :fail
- [x] 4.4 Implement duration_ms injection: merge computed duration_ms into payload fields before evaluation, with server-computed `duration_ms` overriding any client-supplied value
- [x] 4.5 Add changeset validation for alert_rules structure (array of maps with field/op/value keys, op in allowed list, field name limited to flat top-level keys without dotted paths, and `value` restricted to JSON scalars: string/number/boolean/null)
- [x] 4.6 Add tests for all operators, missing fields, type mismatches, boolean/null/scalar handling, multiple rules, and duration injection

## 5. Deadline Worker and App Integration

- [x] 5.1 Create `GI.Monitoring.Workers.HeartbeatDeadline` Oban worker in `:heartbeats` queue using the hardened scheduling model from `harden-check-scheduling` (guaranteed reschedule/recovery semantics, not best-effort chaining)
- [x] 5.2 Implement deadline logic as a locked transition: re-read heartbeat, validate the job's `scheduled_for` against `heartbeat.next_due_at`, and no-op without failure/incident mutation when the heartbeat is paused, stale, or already superseded by a newer due time; otherwise increment consecutive_failures, clear started_at, advance `next_due_at` from the previous due time, and evaluate threshold
- [x] 5.3 Implement incident creation on threshold via the heartbeat lifecycle wrapper so missed deadlines and ping-driven failures share the same create/reopen/archive rules
- [x] 5.4 Implement worker uniqueness on `heartbeat_id` with hardened states excluding `:executing` (use `[:available, :scheduled, :retryable]`) to prevent duplicate deadline chains
- [x] 5.5 Add scheduling helpers: `schedule_deadline/1` and/or `schedule_deadline_from/2` that persist `next_due_at`, compute `scheduled_at` from that anchor, and include `scheduled_for` in job args; add `cancel_deadline/1` to cancel pending jobs for heartbeat
- [x] 5.6 Add Oban `:heartbeats` queue to application config (concurrency: 10)
- [x] 5.7 Extend application startup recovery so active non-paused heartbeat deadline jobs are re-enqueued alongside uptime checks after Oban boots
- [x] 5.8 Add a heartbeat-specific periodic recovery worker that scans active non-paused orphaned/stuck heartbeat deadline jobs between deploys, reusing the stuck-job threshold `attempted_at < now - (5 × interval_seconds)`
- [x] 5.9 Add explicit overdue catch-up behavior for startup and periodic recovery: if an active non-paused heartbeat's `next_due_at` is already in the past, recovery enqueues or processes it immediately at `now`
- [x] 5.10 Register the heartbeat recovery worker on a recurring Oban cron/plugin schedule (or equivalent recurring trigger) and verify it runs periodically in non-test environments
- [x] 5.11 Add tests for deadline firing, skip on recent ping, stale-job invalidation after reschedule/pause/delete, pause behavior, raised exceptions still preserving deadline coverage, recovery scheduling, startup re-enqueue, overdue catch-up, and periodic orphan/stuck recovery

## 6. API Endpoints — Management

- [x] 6.1 Create HeartbeatController and HeartbeatJSON with create, index, show, update, and delete actions nested under projects
- [x] 6.2 Create OpenApiSpex schemas for Heartbeat create responses (full ping URL), update/list/show responses (redacted token-bearing fields), HeartbeatRequest, HeartbeatUpdateRequest, HeartbeatPing, AlertRule, and the paginated ping history response
- [x] 6.3 Add authenticated routes in the existing `/api/v1` read/write scopes: POST/GET /api/v1/projects/:project_id/heartbeats, GET/PATCH/DELETE /api/v1/projects/:project_id/heartbeats/:heartbeat_id
- [x] 6.4 Add heartbeats:read and heartbeats:write to API key valid scopes and keep the dashboard scope editor in sync with the same scope list/source of truth
- [x] 6.5 Add heartbeat controller tests (CRUD, auth, validation, pagination, 404 for project_id mismatch, full token on create responses, redaction on read-only responses)

## 7. API Endpoints — Ping

- [x] 7.1 Create HeartbeatPingController and HeartbeatPingJSON with ping, start, and fail actions
- [x] 7.2 Add public routes in a `/api/v1` scope using `pipe_through :api`: POST /api/v1/projects/:project_id/heartbeats/:heartbeat_token/ping, POST .../ping/start, POST .../ping/fail
- [x] 7.3 Implement token-based auth (no Bearer required) — look up heartbeat by project_id + heartbeat_token, return 404 if not found
- [x] 7.4 Accept optional JSON payload on all public ping routes; on `/ping/fail`, treat `exit_code` as a reserved top-level field persisted separately from `heartbeat_pings.payload`
- [x] 7.5 Add ping controller tests (success/start/fail, invalid token, wrong project, optional payload, exit_code)

## 8. API Endpoints — Ping History

- [x] 8.1 Create HeartbeatPingHistoryController (or action on HeartbeatPingController) for GET /api/v1/projects/:project_id/heartbeats/:heartbeat_id/pings, reusing the heartbeat ping JSON rendering pattern
- [x] 8.2 Add route and tests for paginated ping history retrieval (auth via heartbeats:read scope)

## 9. OpenAPI Spec

- [x] 9.1 Add controller `operation(...)` metadata and OpenApiSpex schemas for heartbeat management endpoints, then regenerate `app/openapi.json` via `mix openapi.spec`
- [x] 9.2 Add explicit `operation(...)` metadata plus request/response schemas for `/ping`, `/ping/start`, and `/ping/fail`, mark those ping endpoint operations with `security: []`, and regenerate `app/openapi.json` so public token-auth routes are documented correctly
- [x] 9.3 Document the ping history endpoint in controller metadata and regenerate `app/openapi.json`
- [x] 9.4 Update the top-level API description in `GIWeb.ApiSpec` so the generated docs no longer claim that every endpoint requires Bearer auth once public ping routes exist
