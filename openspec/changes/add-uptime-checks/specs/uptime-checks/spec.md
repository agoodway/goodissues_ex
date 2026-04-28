## ADDED Requirements

### Requirement: Check Configuration

The system SHALL allow users to create HTTP checks scoped to a project. A check defines a URL to monitor, the HTTP method, expected status code, optional keyword matching, check interval, failure threshold, and reopen window.

#### Scenario: Create a basic HTTP check
- **WHEN** a user creates a check with name "API Health", url "https://api.example.com/health", and project_id
- **THEN** the check is created with method defaulting to "GET", expected_status defaulting to 200, interval_seconds defaulting to 300, failure_threshold defaulting to 1, reopen_window_hours defaulting to 24, paused defaulting to false, and status defaulting to :unknown

#### Scenario: Create a check with keyword matching
- **WHEN** a user creates a check with keyword "OK" and keyword_absence false
- **THEN** the check SHALL verify that the response body contains "OK"

#### Scenario: Create a check with keyword absence
- **WHEN** a user creates a check with keyword "error" and keyword_absence true
- **THEN** the check SHALL verify that the response body does NOT contain "error"

#### Scenario: Validate required fields
- **WHEN** a user creates a check without name or url
- **THEN** the creation fails with validation errors

#### Scenario: Validate interval bounds
- **WHEN** a user creates a check with interval_seconds less than 30 or greater than 3600
- **THEN** the creation fails with a validation error

### Requirement: Check Scheduling

The system SHALL execute checks at their configured interval using self-rescheduling Oban workers. Creating a check enqueues the first job. Each execution schedules the next.

#### Scenario: First job enqueued on check creation
- **WHEN** a check is created with paused false
- **THEN** an Oban job is inserted for the check, scheduled to run immediately

#### Scenario: Paused check is not enqueued
- **WHEN** a check is created with paused true
- **THEN** no Oban job is inserted

#### Scenario: Job reschedules itself
- **WHEN** a check job executes for a check with interval_seconds 60
- **THEN** a new job is scheduled to run in 60 seconds
- **AND** the new job has a unique constraint on check_id to prevent duplicates

#### Scenario: Paused check stops rescheduling
- **WHEN** a check job executes and the check is paused
- **THEN** no new job is scheduled
- **AND** the check is not executed

#### Scenario: Resuming a paused check
- **WHEN** a paused check is updated to paused false
- **THEN** an Oban job is inserted to run immediately

#### Scenario: Deleting a check cancels pending jobs
- **WHEN** a check is deleted
- **THEN** any pending Oban jobs for that check are cancelled

#### Scenario: Restart recovery re-enqueues orphaned checks
- **WHEN** the application starts
- **THEN** any active non-paused check with no pending Oban job SHALL have a job inserted

### Requirement: Check Execution

The system SHALL execute HTTP checks using Req and record the result.

#### Scenario: Successful check
- **WHEN** a check executes against a URL that returns the expected status code
- **THEN** a check_result is created with status :up, the response status_code, and response_ms
- **AND** the check's consecutive_failures is reset to 0
- **AND** the check's status is set to :up
- **AND** the check's last_checked_at is updated

#### Scenario: Failed check — wrong status code
- **WHEN** a check executes and receives a status code different from expected_status
- **THEN** a check_result is created with status :down, the actual status_code, and response_ms
- **AND** the check's consecutive_failures is incremented by 1

#### Scenario: Failed check — connection error
- **WHEN** a check executes and the HTTP request fails (timeout, DNS error, connection refused)
- **THEN** a check_result is created with status :down, null status_code, and the error message
- **AND** the check's consecutive_failures is incremented by 1

#### Scenario: Failed check — keyword not found
- **WHEN** a check with keyword "OK" and keyword_absence false executes and the response body does not contain "OK"
- **THEN** a check_result is created with status :down and error "keyword not found: OK"

#### Scenario: Failed check — keyword present when absence expected
- **WHEN** a check with keyword "error" and keyword_absence true executes and the response body contains "error"
- **THEN** a check_result is created with status :down and error "keyword present: error"

#### Scenario: Check execution timeout
- **WHEN** a check executes and the HTTP request does not complete within 30 seconds
- **THEN** the request is aborted and a check_result is created with status :down and error "timeout"

### Requirement: Check CRUD API

The system SHALL provide REST API endpoints for managing checks.

#### Scenario: Create check via API
- **WHEN** POST /api/v1/projects/:project_id/checks with valid check params and an API key with checks:write scope
- **THEN** the check is created and returned with 201 status

#### Scenario: List checks for a project
- **WHEN** GET /api/v1/projects/:project_id/checks with an API key with checks:read scope
- **THEN** checks are returned in a paginated envelope with data (array of checks), and meta (page, per_page, total, total_pages)

#### Scenario: Get a single check
- **WHEN** GET /api/v1/projects/:project_id/checks/:check_id with an API key with checks:read scope
- **THEN** the check is returned with its current status and last_checked_at

#### Scenario: Member routes enforce project scoping
- **WHEN** GET, PATCH, or DELETE `/api/v1/projects/:project_id/checks/:check_id` with a `project_id` that does not own `check_id`
- **THEN** the response is 404 Not Found

#### Scenario: Update a check
- **WHEN** PATCH /api/v1/projects/:project_id/checks/:check_id with updated params and an API key with checks:write scope
- **THEN** the check is updated and returned

#### Scenario: Delete a check
- **WHEN** DELETE /api/v1/projects/:project_id/checks/:check_id with an API key with checks:write scope
- **THEN** the check is deleted and pending jobs are cancelled
- **AND** 204 is returned

### Requirement: Check Result Storage

The system SHALL store check results as an append-only log.

#### Scenario: Check result fields
- **WHEN** a check result is created
- **THEN** it stores status (enum: :up, :down), status_code (nullable integer), response_ms (integer), error (nullable text), checked_at (utc_datetime), check_id (FK), and issue_id (nullable FK)

#### Scenario: Check results are immutable
- **WHEN** a check result exists
- **THEN** it cannot be updated or deleted individually

#### Scenario: Check results API listing
- **WHEN** GET /api/v1/projects/:project_id/checks/:check_id/results with an API key with checks:read scope
- **THEN** check results are returned in reverse chronological order in a paginated envelope with data (array of results), and meta (page, per_page, total, total_pages)

#### Scenario: Check results route enforces project scoping
- **WHEN** GET `/api/v1/projects/:project_id/checks/:check_id/results` with a `project_id` that does not own `check_id`
- **THEN** the response is 404 Not Found

#### Scenario: Cascade deletion
- **WHEN** a check is deleted
- **THEN** all associated check_results are deleted
