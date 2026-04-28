## ADDED Requirements

### Requirement: Heartbeat CRUD scoped to projects
The system SHALL allow users to create, list, show, update, and delete heartbeat monitors scoped to a project. Each heartbeat MUST have a name, interval_seconds (30–86400), grace_seconds (0–86400), and an auto-generated unique 42-character ping token. Optional fields: failure_threshold (default 1), reopen_window_hours (default 24), paused (default false), alert_rules (default []).

#### Scenario: Create a heartbeat
- **WHEN** a user sends POST /api/v1/projects/:project_id/heartbeats with name "nightly-backup" and interval_seconds 86400 and grace_seconds 1800
- **THEN** the system creates a heartbeat with status :new, generates a unique 42-char ping_token, and returns the heartbeat with its ping URL

#### Scenario: Create heartbeat with invalid interval
- **WHEN** a user sends POST with interval_seconds 10 (below minimum 30)
- **THEN** the system returns a 422 validation error

#### Scenario: List heartbeats for a project
- **WHEN** a user sends GET /api/v1/projects/:project_id/heartbeats
- **THEN** the system returns all heartbeats belonging to that project in paginated envelope format

#### Scenario: Update a heartbeat
- **WHEN** a user sends PATCH /api/v1/projects/:project_id/heartbeats/:id with interval_seconds 3600
- **THEN** the system updates the interval and reschedules the deadline job accordingly

#### Scenario: Delete a heartbeat
- **WHEN** a user sends DELETE /api/v1/projects/:project_id/heartbeats/:id
- **THEN** the system deletes the heartbeat, all associated pings, and cancels pending deadline jobs

#### Scenario: Heartbeat scoped to project
- **WHEN** a user requests a heartbeat that belongs to a different project
- **THEN** the system returns 404

### Requirement: Ping token uniqueness and generation
The system SHALL generate a cryptographically random 42-character URL-safe token for each heartbeat. Tokens MUST be unique across all heartbeats in the system.

#### Scenario: Token generation on create
- **WHEN** a heartbeat is created
- **THEN** the system generates a 42-char token using :crypto.strong_rand_bytes and Base.url_encode64

#### Scenario: Token uniqueness enforced
- **WHEN** a token collision occurs (statistically improbable)
- **THEN** the database unique constraint prevents the insert and the system retries with a new token

### Requirement: Receive success ping
The system SHALL accept POST requests to /api/v1/projects/:project_id/heartbeats/:token/ping as a success signal. The request body MAY contain a JSON payload. On receiving a success ping, the system MUST record a HeartbeatPing with kind :ping, update last_ping_at, reset the deadline timer, and evaluate alert rules against the payload. When the ping is a logical success, the system MUST reset consecutive_failures.

#### Scenario: Success ping with no body
- **WHEN** a job sends POST to /ping with no body
- **THEN** the system records a ping, updates last_ping_at, resets consecutive_failures to 0, sets status to :up if previously :new or :down with passing alert rules, and reschedules the deadline job

#### Scenario: Success ping with JSON payload
- **WHEN** a job sends POST to /ping with body {"rows_processed": 500}
- **THEN** the system records a ping with the payload stored, and evaluates alert_rules against the payload fields

#### Scenario: Ping with invalid token
- **WHEN** a request is sent to /ping with a token that doesn't exist
- **THEN** the system returns 404

#### Scenario: Ping with mismatched project_id
- **WHEN** a request is sent with a valid token but wrong project_id
- **THEN** the system returns 404

### Requirement: Receive start ping
The system SHALL accept POST requests to /api/v1/projects/:project_id/heartbeats/:token/ping/start to signal that a job has begun execution. The system MUST set started_at on the heartbeat and record a HeartbeatPing with kind :start.

#### Scenario: Start ping received
- **WHEN** a job sends POST to /ping/start
- **THEN** the system records a ping with kind :start and sets heartbeat.started_at to current time

#### Scenario: Start then success computes duration
- **WHEN** a job sends /ping/start, then sends /ping 30 seconds later
- **THEN** the success ping record has duration_ms ≈ 30000 and heartbeat.started_at is cleared

### Requirement: Receive fail ping
The system SHALL accept POST requests to /api/v1/projects/:project_id/heartbeats/:token/ping/fail to signal immediate job failure. On receiving a fail ping, the system MUST increment consecutive_failures, record a HeartbeatPing with kind :fail, and immediately evaluate the incident threshold (no waiting for deadline).

#### Scenario: Fail ping triggers incident
- **WHEN** a job sends /ping/fail and consecutive_failures reaches failure_threshold
- **THEN** the system creates an incident issue via the existing incident lifecycle using the bot user

#### Scenario: Fail ping with exit code
- **WHEN** a job sends /ping/fail with body {"exit_code": 1}
- **THEN** the system records the ping with exit_code 1

### Requirement: Deadline detection via self-rescheduling worker
The system SHALL schedule per-heartbeat Oban deadline jobs. A deadline job fires at last_ping_at + interval_seconds + grace_seconds. If no ping has arrived by deadline, the system MUST increment consecutive_failures and evaluate the incident threshold.

#### Scenario: Deadline fires with no ping received
- **WHEN** a deadline job fires and last_ping_at has not been updated since the job was scheduled
- **THEN** the system increments consecutive_failures, sets status to :down if threshold met, triggers incident lifecycle, and schedules the next deadline

#### Scenario: Ping arrived before deadline fires
- **WHEN** a deadline job fires but last_ping_at shows a ping arrived after the job was scheduled
- **THEN** the system skips failure processing (the ping reception already rescheduled the deadline)

#### Scenario: Paused heartbeat does not reschedule
- **WHEN** a deadline fires for a paused heartbeat
- **THEN** the system does not schedule another deadline job

#### Scenario: Heartbeat creation schedules first deadline
- **WHEN** a heartbeat is created with paused: false
- **THEN** the system schedules a deadline job for now + interval_seconds + grace_seconds

#### Scenario: Resuming a paused heartbeat
- **WHEN** a heartbeat is updated from paused: true to paused: false
- **THEN** the system schedules a deadline job for now + interval_seconds + grace_seconds

#### Scenario: Application restart recovers missing deadline jobs
- **WHEN** the application starts and an active non-paused heartbeat has no pending deadline job
- **THEN** the system enqueues the next deadline job for that heartbeat

### Requirement: Incident lifecycle integration
The system SHALL use the existing incident lifecycle (create_or_reopen_incident/3, archive_incident/2) when heartbeat failures cross the threshold or when a heartbeat recovers. The bot user MUST be the submitter for auto-created incidents.

#### Scenario: Consecutive failures reach threshold
- **WHEN** consecutive_failures >= failure_threshold after a missed deadline or fail ping
- **THEN** the system calls create_or_reopen_incident with the bot user, sets current_issue_id on the heartbeat

#### Scenario: Recovery after being down
- **WHEN** a success ping arrives and heartbeat status is :down and alert rules pass
- **THEN** the system archives the open incident, clears current_issue_id, resets consecutive_failures to 0, sets status to :up

#### Scenario: Reopen within window
- **WHEN** a heartbeat fails again within reopen_window_hours of a previously closed incident
- **THEN** the system reopens the existing incident instead of creating a new one

### Requirement: Ping history retrieval
The system SHALL provide a paginated list of pings for a heartbeat via GET /api/v1/projects/:project_id/heartbeats/:id/pings in reverse chronological order.

#### Scenario: List pings
- **WHEN** a user sends GET /api/v1/projects/:project_id/heartbeats/:id/pings
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
- **WHEN** a request with no Authorization header calls POST /api/v1/projects/:project_id/heartbeats/:token/ping
- **THEN** the system processes the ping using only the token for authentication
