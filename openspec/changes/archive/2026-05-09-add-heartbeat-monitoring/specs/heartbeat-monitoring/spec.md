## ADDED Requirements

### Requirement: Heartbeat CRUD scoped to projects
The system SHALL allow users to create, list, show, update, and delete heartbeat monitors scoped to a project. Each heartbeat MUST have a name, interval_seconds (30–86400), grace_seconds (0–86400), an auto-generated unique 42-character ping token, and a persisted `next_due_at` scheduling anchor. Optional fields: failure_threshold (default 1), reopen_window_hours (default 24), paused (default false), alert_rules (default []).

#### Scenario: Create a heartbeat
- **WHEN** a user sends POST /api/v1/projects/:project_id/heartbeats with name "nightly-backup" and interval_seconds 86400 and grace_seconds 1800
- **THEN** the system creates a heartbeat with status :unknown, generates a unique 42-char ping_token, and returns the heartbeat with its ping URL

#### Scenario: Create heartbeat with invalid interval
- **WHEN** a user sends POST with interval_seconds 10 (below minimum 30)
- **THEN** the system returns a 422 validation error

#### Scenario: Create heartbeat response status
- **WHEN** a user successfully creates a heartbeat
- **THEN** the response status is `201 Created`

#### Scenario: List heartbeats for a project
- **WHEN** a user sends GET /api/v1/projects/:project_id/heartbeats
- **THEN** the system returns all heartbeats belonging to that project in paginated envelope format ordered consistently with the existing monitoring list views

#### Scenario: Update a heartbeat
- **WHEN** a user sends PATCH /api/v1/projects/:project_id/heartbeats/:heartbeat_id with interval_seconds 3600
- **THEN** the system updates the interval and reschedules the deadline job accordingly

#### Scenario: Delete a heartbeat
- **WHEN** a user sends DELETE /api/v1/projects/:project_id/heartbeats/:heartbeat_id
- **THEN** the system deletes the heartbeat, all associated pings, and cancels pending deadline jobs

#### Scenario: Delete heartbeat leaves existing incident issue unchanged
- **WHEN** a heartbeat with an existing linked incident is deleted
- **THEN** the heartbeat and its pings are removed
- **AND** the existing incident issue is left unchanged rather than auto-archived by the delete action

#### Scenario: Delete heartbeat response status
- **WHEN** a user successfully deletes a heartbeat
- **THEN** the response status is `204 No Content`

#### Scenario: Heartbeat scoped to project
- **WHEN** a user requests a heartbeat that belongs to a different project
- **THEN** the system returns 404

#### Scenario: Create returns full ping URL
- **WHEN** a user creates a heartbeat with write permission
- **THEN** the create response includes the full ping URL derived from the generated token so the caller can provision the external job

#### Scenario: Read responses redact token-bearing fields
- **WHEN** a caller fetches heartbeat management data after creation (including list, show, or update responses)
- **THEN** the response omits or masks `ping_token` and full ping URLs so post-create management reads cannot be used to send public pings

### Requirement: Ping token uniqueness and generation
The system SHALL generate a cryptographically random 42-character URL-safe token for each heartbeat. Tokens MUST be unique across all heartbeats in the system.

#### Scenario: Token generation on create
- **WHEN** a heartbeat is created
- **THEN** the system generates a 42-char token using :crypto.strong_rand_bytes and Base.url_encode64

#### Scenario: Token uniqueness enforced
- **WHEN** a token collision occurs (statistically improbable)
- **THEN** the database unique constraint prevents the insert and the system retries with a new token

### Requirement: Receive success ping
The system SHALL accept POST requests to /api/v1/projects/:project_id/heartbeats/:heartbeat_token/ping as a success signal. The request body MAY contain a JSON payload. On receiving a success ping, the system MUST record a HeartbeatPing with kind :ping, update last_ping_at, reset the deadline timer by advancing `next_due_at`, and evaluate alert rules against the payload. When the ping is a logical success, the system MUST reset consecutive_failures.

#### Scenario: Success ping with no body
- **WHEN** a job sends POST to /ping with no body
- **THEN** the system records a ping, updates last_ping_at, resets consecutive_failures to 0, sets status to :up if previously :unknown or :down with passing alert rules, and reschedules the deadline job

#### Scenario: Success ping advances the scheduling anchor
- **WHEN** a logical success ping is received
- **THEN** the system updates `next_due_at` to `now + interval_seconds + grace_seconds`
- **AND** the next deadline job is scheduled from that new due time

#### Scenario: Success ping with JSON payload
- **WHEN** a job sends POST to /ping with body {"rows_processed": 500}
- **THEN** the system records a ping with the payload stored, and evaluates alert_rules against the payload fields

#### Scenario: Success ping can still be a logical failure
- **WHEN** a job sends POST to /ping, the ping is recorded, and an alert rule matches the payload or computed duration
- **THEN** the system treats the received ping as a failure, increments consecutive_failures, evaluates the incident threshold immediately, and sets the heartbeat to `:down` when the threshold is reached

#### Scenario: Ping with invalid token
- **WHEN** a request is sent to /ping with a token that doesn't exist
- **THEN** the system returns 404

#### Scenario: Ping with mismatched project_id
- **WHEN** a request is sent with a valid token but wrong project_id
- **THEN** the system returns 404

#### Scenario: Success ping response
- **WHEN** a job sends a valid POST to `/ping`
- **THEN** the system responds with `204 No Content`

### Requirement: Receive start ping
The system SHALL accept POST requests to /api/v1/projects/:project_id/heartbeats/:heartbeat_token/ping/start to signal that a job has begun execution. The system MUST set started_at on the heartbeat, record a HeartbeatPing with kind :start, and persist any supplied JSON payload.

#### Scenario: Start ping received
- **WHEN** a job sends POST to /ping/start
- **THEN** the system records a ping with kind :start and sets heartbeat.started_at to current time

#### Scenario: Start then success computes duration
- **WHEN** a job sends /ping/start, then sends /ping 30 seconds later
- **THEN** the success ping record has duration_ms ≈ 30000 and heartbeat.started_at is cleared

#### Scenario: Start ping response
- **WHEN** a job sends a valid POST to `/ping/start`
- **THEN** the system responds with `204 No Content`

#### Scenario: Start ping stores payload
- **WHEN** a job sends POST to `/ping/start` with a JSON body
- **THEN** the system stores that body in `heartbeat_pings.payload`

### Requirement: Receive fail ping
The system SHALL accept POST requests to /api/v1/projects/:project_id/heartbeats/:heartbeat_token/ping/fail to signal immediate job failure. On receiving a fail ping, the system MUST increment consecutive_failures, record a HeartbeatPing with kind :fail, persist any supplied JSON payload, advance `next_due_at`, and immediately evaluate the incident threshold (no waiting for deadline).

#### Scenario: Fail ping triggers incident
- **WHEN** a job sends /ping/fail and consecutive_failures reaches failure_threshold
- **THEN** the system sets the heartbeat to `:down`
- **AND** the system creates an incident issue via the heartbeat lifecycle wrapper using the bot user

#### Scenario: Fail ping with exit code
- **WHEN** a job sends /ping/fail with body {"exit_code": 1}
- **THEN** the system records the ping with exit_code 1

#### Scenario: Fail ping reserves exit_code outside payload storage
- **WHEN** a job sends `/ping/fail` with body {"exit_code": 1, "reason": "backup failed"}
- **THEN** the system stores `exit_code = 1` on the ping record
- **AND** stores the remaining JSON fields in `heartbeat_pings.payload` without duplicating `exit_code`

#### Scenario: Fail ping clears pending start state
- **WHEN** a job previously sent `/ping/start` and later sends `/ping/fail`
- **THEN** the system clears `started_at` so a future success ping cannot compute duration from the failed run

#### Scenario: Fail ping resets the deadline window
- **WHEN** a job sends `/ping/fail`
- **THEN** the system updates `next_due_at` to `now + interval_seconds + grace_seconds`
- **AND** cancels or supersedes the previously pending deadline job so the failed run is not counted twice

#### Scenario: Fail ping response
- **WHEN** a job sends a valid POST to `/ping/fail`
- **THEN** the system responds with `204 No Content`

#### Scenario: Fail ping stores payload
- **WHEN** a job sends POST to `/ping/fail` with a JSON body
- **THEN** the system stores the non-`exit_code` remainder of that body in `heartbeat_pings.payload`

### Requirement: Deadline detection via hardened self-rescheduling worker
The system SHALL schedule per-heartbeat Oban deadline jobs anchored to persisted `next_due_at`. The deadline chain SHALL preserve monitoring coverage even when deadline processing raises, and stale deadline jobs SHALL no-op instead of mutating heartbeat state after a newer due time has been established. If no ping has arrived by deadline, the system MUST increment consecutive_failures and evaluate the incident threshold.

#### Scenario: Unique-state contract excludes executing jobs
- **WHEN** the deadline worker self-reschedules
- **THEN** its uniqueness contract keys on `heartbeat_id`
- **AND** uniqueness only considers `available`, `scheduled`, and `retryable` jobs
- **AND** the in-flight `executing` job does not block insertion of the next deadline job

#### Scenario: Deadline fires with no ping received
- **WHEN** a deadline job fires and its `scheduled_for` still matches the heartbeat's current `next_due_at`
- **THEN** the system increments consecutive_failures, sets status to :down if threshold met, triggers incident lifecycle, advances `next_due_at` from the prior due time, and schedules the next deadline

#### Scenario: Deadline job is superseded before it fires
- **WHEN** a deadline job fires but the heartbeat's current `next_due_at` no longer matches that job's `scheduled_for`
- **THEN** the system skips failure processing because a newer success, fail, pause, or reschedule event already superseded that deadline window

#### Scenario: Stale deadline job after reschedule does not apply failure
- **WHEN** a deadline job fires but the heartbeat's current `next_due_at` no longer matches the job's original scheduled due time
- **THEN** the stale job does not mutate heartbeat state or schedule a new failure chain

#### Scenario: Paused heartbeat does not reschedule
- **WHEN** a deadline fires for a paused heartbeat
- **THEN** the system does not schedule another deadline job
- **AND** the paused deadline does not increment failures or trigger incident lifecycle

#### Scenario: Deleted heartbeat no-ops a late deadline job
- **WHEN** a deadline job fires after the heartbeat was deleted
- **THEN** the worker exits without mutating state, triggering incident lifecycle, or scheduling another deadline

#### Scenario: Raised exception does not break deadline coverage
- **WHEN** deadline processing raises after the worker begins handling a heartbeat
- **THEN** the hardened scheduling contract still preserves future deadline coverage through guaranteed reschedule/recovery semantics

#### Scenario: Heartbeat creation schedules first deadline
- **WHEN** a heartbeat is created with paused: false
- **THEN** the system schedules a deadline job for now + interval_seconds + grace_seconds

#### Scenario: Resuming a paused heartbeat
- **WHEN** a heartbeat is updated from paused: true to paused: false
- **THEN** the system schedules a deadline job for now + interval_seconds + grace_seconds

#### Scenario: Application restart recovers missing deadline jobs
- **WHEN** the application starts and an active non-paused heartbeat has no pending deadline job
- **THEN** the system enqueues the next deadline job for that heartbeat

#### Scenario: Periodic recovery restores orphaned or stuck deadline jobs
- **WHEN** an active non-paused heartbeat loses its deadline job chain or its deadline job remains stuck in execution with `attempted_at < now - (5 × interval_seconds)`
- **THEN** the hardened monitoring recovery path re-enqueues the appropriate deadline job without waiting for an application restart

#### Scenario: Overdue heartbeat is recovered immediately after downtime
- **WHEN** the application restarts or the heartbeat-specific periodic recovery worker examines a heartbeat whose `next_due_at` is already in the past
- **THEN** recovery enqueues or processes the overdue deadline immediately rather than waiting another full interval

### Requirement: Incident lifecycle integration
The system SHALL use a heartbeat-specific lifecycle wrapper or generalized lifecycle path that preserves the existing create/reopen/archive incident rules when heartbeat failures cross the threshold or when a heartbeat recovers. The bot user MUST be the submitter for auto-created incidents.

#### Scenario: Consecutive failures reach threshold
- **WHEN** consecutive_failures >= failure_threshold after a missed deadline, fail ping, or alert-rule-triggered logical failure on a received ping
- **THEN** the system calls create_or_reopen_incident with the bot user, sets current_issue_id on the heartbeat

#### Scenario: Recovery after being down
- **WHEN** a success ping arrives and heartbeat status is :down and alert rules pass
- **THEN** the system archives the open incident, clears current_issue_id, resets consecutive_failures to 0, sets status to :up

#### Scenario: Reopen within window
- **WHEN** a heartbeat fails again within reopen_window_hours of a previously closed incident
- **THEN** the system reopens the existing incident instead of creating a new one

### Requirement: Ping history retrieval
The system SHALL provide a paginated list of pings for a heartbeat via GET /api/v1/projects/:project_id/heartbeats/:heartbeat_id/pings in reverse chronological order.

#### Scenario: List pings
- **WHEN** a user sends GET /api/v1/projects/:project_id/heartbeats/:heartbeat_id/pings
- **THEN** the system returns pings in reverse chronological order with paginated envelope

#### Scenario: Pings include computed duration
- **WHEN** a ping was preceded by a /start ping
- **THEN** the ping record in the response includes duration_ms

### Requirement: API key scopes for heartbeats
The system SHALL add heartbeats:read and heartbeats:write to the valid API key scopes. Heartbeat management endpoints MUST require appropriate scopes. Ping endpoints MUST NOT require API key auth (token in URL is sufficient).

#### Scenario: Read scope allows listing
- **WHEN** a request with heartbeats:read scope calls GET /api/v1/projects/:project_id/heartbeats
- **THEN** the system allows the request

#### Scenario: Write scope required for create
- **WHEN** a request without heartbeats:write scope calls POST /api/v1/projects/:project_id/heartbeats
- **THEN** the system returns 403

#### Scenario: Ping endpoints require no API key
- **WHEN** a request with no Authorization header calls POST /api/v1/projects/:project_id/heartbeats/:heartbeat_token/ping
- **THEN** the system processes the ping using only the token for authentication
