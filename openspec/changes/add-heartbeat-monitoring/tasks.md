## 0. Dependencies

- [ ] 0.1 Reconcile with or wait for `add-uptime-checks` so `FF.Monitoring`, the incident lifecycle, and bot-user support exist before heartbeat implementation begins

## 1. Database & Schemas

- [ ] 1.1 Create migration for heartbeats table (id, name, ping_token varchar(42) unique, interval_seconds, grace_seconds, failure_threshold, reopen_window_hours, status, consecutive_failures, last_ping_at, started_at, current_issue_id FK, project_id FK, created_by_id FK, alert_rules jsonb default [], paused boolean default false, timestamps)
- [ ] 1.2 Create migration for heartbeat_pings table (id, kind enum(:ping, :start, :fail), exit_code integer nullable, payload jsonb nullable, duration_ms integer nullable, pinged_at utc_datetime_usec, heartbeat_id FK on_delete: :delete_all, issue_id FK nullable)
- [ ] 1.3 Create FF.Monitoring.Heartbeat Ecto schema with validations (name required, interval_seconds 30..86400, grace_seconds 0..86400, failure_threshold >= 1, reopen_window_hours >= 1, alert_rules validated structure)
- [ ] 1.4 Create FF.Monitoring.HeartbeatPing Ecto schema (read-only, no update changeset)
- [ ] 1.5 Add ping_token generation using :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false) |> binary_part(0, 42) with retry on unique constraint violation

## 2. Monitoring Context — Heartbeat CRUD

- [ ] 2.1 Add create_heartbeat/3 (project, user, attrs) — generates token, inserts heartbeat, enqueues first deadline job unless paused
- [ ] 2.2 Add list_heartbeats/2 (project, pagination params) — paginated, reverse chronological
- [ ] 2.3 Add get_heartbeat!/2 (project, id) — scoped to project, raises on not found
- [ ] 2.4 Add get_heartbeat_by_token!/2 (project_id, token) — for ping endpoint lookup
- [ ] 2.5 Add update_heartbeat/3 (heartbeat, user, attrs) — updates fields, reschedules deadline if interval/grace changed, enqueues deadline on resume from paused
- [ ] 2.6 Add delete_heartbeat/2 (project, id) — deletes heartbeat and cancels pending Oban jobs
- [ ] 2.7 Add tests for all heartbeat CRUD functions

## 3. Ping Reception

- [ ] 3.1 Add receive_ping/3 (heartbeat, kind, attrs) — records HeartbeatPing, updates heartbeat state based on kind
- [ ] 3.2 Implement success ping logic: update last_ping_at, compute duration_ms if started_at set, clear started_at, cancel current deadline, schedule new deadline, evaluate alert rules, and reset consecutive_failures when the ping is a logical success
- [ ] 3.3 Implement start ping logic: set heartbeat.started_at, record ping with kind :start
- [ ] 3.4 Implement fail ping logic: increment consecutive_failures, record ping with kind :fail, evaluate incident threshold immediately
- [ ] 3.5 Implement recovery logic: when success ping arrives and status is :down and alert rules pass, archive incident, clear current_issue_id, reset consecutive_failures, set status :up
- [ ] 3.6 Add list_heartbeat_pings/2 (heartbeat, pagination params) — paginated reverse chronological
- [ ] 3.7 Add tests for ping reception (all three kinds), duration computation, and recovery

## 4. Alert Rule Evaluation

- [ ] 4.1 Create FF.Monitoring.AlertRuleEvaluator module with evaluate/2 (rules, payload_with_duration) → :pass | :fail
- [ ] 4.2 Implement operator evaluation: eq, neq, gt, gte, lt, lte with type coercion (skip rule on type mismatch or missing field)
- [ ] 4.3 Implement ANY-match semantics: if any rule fires, return :fail
- [ ] 4.4 Implement duration_ms injection: merge computed duration_ms into payload fields before evaluation
- [ ] 4.5 Add changeset validation for alert_rules structure (array of maps with field/op/value keys, op in allowed list)
- [ ] 4.6 Add tests for all operators, missing fields, type mismatches, multiple rules, and duration injection

## 5. Deadline Worker

- [ ] 5.1 Create FF.Monitoring.Workers.HeartbeatDeadline Oban worker in :heartbeats queue with self-rescheduling pattern
- [ ] 5.2 Implement deadline logic: re-read heartbeat, check if last_ping_at is newer than scheduled time (skip if ping arrived), otherwise increment consecutive_failures and evaluate threshold
- [ ] 5.3 Implement incident creation on threshold: call create_or_reopen_incident/3 via existing incident lifecycle with bot user
- [ ] 5.4 Implement unique constraint on heartbeat_id to prevent duplicate deadline chains
- [ ] 5.5 Add scheduling helpers: schedule_deadline/1 (computes scheduled_at from last_ping_at or now + interval + grace), cancel_deadline/1 (cancels pending jobs for heartbeat)
- [ ] 5.6 Add Oban :heartbeats queue to application config (concurrency: 10)
- [ ] 5.7 Add startup recovery: re-enqueue deadline jobs for active heartbeats that have no pending job after Oban boots
- [ ] 5.8 Add tests for deadline firing, skip on recent ping, pause behavior, recovery scheduling, and startup re-enqueue

## 6. API Endpoints — Management

- [ ] 6.1 Create HeartbeatController and HeartbeatJSON with create, index, show, update, and delete actions nested under projects
- [ ] 6.2 Create OpenApiSpex schemas for Heartbeat, HeartbeatRequest, HeartbeatUpdateRequest, HeartbeatPing, AlertRule, and the paginated ping history response
- [ ] 6.3 Add authenticated routes in the existing `/api/v1` read/write scopes: POST/GET /api/v1/projects/:project_id/heartbeats, GET/PATCH/DELETE /api/v1/projects/:project_id/heartbeats/:id
- [ ] 6.4 Add heartbeats:read and heartbeats:write to API key valid scopes and keep the dashboard scope editor in sync with the same scope list/source of truth
- [ ] 6.5 Add heartbeat controller tests (CRUD, auth, validation, pagination, 404 for project_id mismatch)

## 7. API Endpoints — Ping

- [ ] 7.1 Create HeartbeatPingController and HeartbeatPingJSON with ping, start, and fail actions
- [ ] 7.2 Add public routes in a `/api/v1` scope using `pipe_through :api`: POST /api/v1/projects/:project_id/heartbeats/:token/ping, POST .../ping/start, POST .../ping/fail
- [ ] 7.3 Implement token-based auth (no Bearer required) — look up heartbeat by project_id + token, return 404 if not found
- [ ] 7.4 Accept optional JSON body with payload fields and exit_code
- [ ] 7.5 Add ping controller tests (success/start/fail, invalid token, wrong project, optional payload, exit_code)

## 8. API Endpoints — Ping History

- [ ] 8.1 Create HeartbeatPingHistoryController (or action on HeartbeatPingController) for GET /api/v1/projects/:project_id/heartbeats/:id/pings, reusing the heartbeat ping JSON rendering pattern
- [ ] 8.2 Add route and tests for paginated ping history retrieval (auth via heartbeats:read scope)

## 9. OpenAPI Spec

- [ ] 9.1 Add controller `operation(...)` metadata and OpenApiSpex schemas for heartbeat management endpoints, then regenerate `app/openapi.json` via `mix openapi.spec`
- [ ] 9.2 Mark ping endpoint operations with `security: []` and regenerate `app/openapi.json` so public token-auth routes are documented correctly
- [ ] 9.3 Document the ping history endpoint in controller metadata and regenerate `app/openapi.json`
