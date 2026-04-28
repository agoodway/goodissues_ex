## 1. Issue Type Extension

- [x] 1.1 Update Issue schema @type_values to include :incident
- [x] 1.2 Update IssueType OpenAPI schema enum in lib/app_web/controllers/api/v1/schemas/issue.ex to include "incident"
- [x] 1.3 Update @valid_types in lib/app/tracking.ex to include "incident" (or derive from Issue.type_values/0)
- [x] 1.4 Update openapi.json with :incident in issue type enum
- [x] 1.5 Add tests for creating and filtering issues with type :incident
- [x] 1.6 Update dashboard issue list/detail labels, project recent-issue badges, and type filter to display and filter :incident issues without exposing incident in manual issue creation forms
- [x] 1.7 Add LiveView tests for displaying and filtering incident issues in dashboard issue and project views, plus preserving manual form type options

## 2. Bot User

- [x] 2.1 Add get_or_create_bot_user!/1 function to App.Accounts context — creates a passwordless user with email "bot@{account_id}.fruitfly.internal" and account membership if not exists (wrap in Repo.transaction to avoid orphaned users; do not use register_user/1 because it creates a default personal account)
- [x] 2.2 Add tests for bot user creation, idempotency, and authentication failure

## 3. Database & Schemas

- [x] 3.1 Create migration for checks table (id, name, url, method, interval_seconds, expected_status, keyword, keyword_absence, paused, status, failure_threshold, reopen_window_hours, consecutive_failures, last_checked_at, current_issue_id, project_id, created_by_id, timestamps) — use on_delete: :delete_all for project_id FK
- [x] 3.2 Create migration for check_results table (id, status, status_code, response_ms, error, checked_at, check_id, issue_id)
- [x] 3.3 Create App.Monitoring.Check Ecto schema with validations (name required, url required, interval_seconds 30..3600, method in GET/HEAD/POST, failure_threshold >= 1, reopen_window_hours >= 1)
- [x] 3.4 Create App.Monitoring.CheckResult Ecto schema (read-only, no update changeset)

## 4. Monitoring Context

- [x] 4.1 Create App.Monitoring context with CRUD functions for checks (create_check/3, get_check!/2, list_checks/2, update_check/3, delete_check/2)
- [x] 4.2 Add list_check_results/2 with pagination (reverse chronological)
- [x] 4.3 Add create_check_result/2 internal function for recording results
- [x] 4.4 Add find_incident_issue/2 function — finds open or recently-closed incident issue for a check
- [x] 4.5 Add tests for all monitoring context functions

## 5. Check Execution Worker

- [x] 5.1 Create App.Workers.CheckRunner Oban worker in :checks queue with self-rescheduling pattern
- [x] 5.2 Implement HTTP check execution using Req (GET/HEAD/POST to url, configurable 30s timeout)
- [x] 5.3 Implement keyword matching logic (presence and absence)
- [x] 5.4 Implement result recording — create check_result, update check status and consecutive_failures
- [x] 5.5 Implement incident creation logic — when consecutive_failures >= failure_threshold, call into incident lifecycle
- [x] 5.6 Implement recovery logic — when check passes after being :down, archive open incident and clear current_issue_id
- [x] 5.7 Implement unique constraint on jobs to prevent duplicate chains
- [x] 5.8 Add Oban :checks queue to application config (concurrency: 10)
- [x] 5.9 Add tests for check execution, rescheduling, pause behavior, and error handling

## 6. Incident Lifecycle

- [x] 6.1 Implement create_or_reopen_incident/3 — creates new incident issue or reopens a recently-closed one within reopen_window_hours, using bot user as submitter
- [x] 6.2 Implement archive_incident/2 — archives open incident issue and clears check.current_issue_id
- [x] 6.3 Add tests for incident creation, reopening within window, new incident outside window, and recovery archival

## 7. API Endpoints

- [x] 7.1 Create CheckController with create, index, show, update, delete actions nested under projects
- [x] 7.2 Create CheckResultController with index action nested under projects and checks
- [x] 7.3 Create OpenApiSpex schemas for Check, CheckResult, CheckRequest, CheckUpdateRequest
- [x] 7.4 Add routes: POST/GET /api/v1/projects/:project_id/checks, GET/PATCH/DELETE /api/v1/projects/:project_id/checks/:check_id, GET /api/v1/projects/:project_id/checks/:check_id/results
- [x] 7.5 Add `checks:read` and `checks:write` to API key valid scopes and dashboard API key scope editor, with tests
- [x] 7.6 Add check controller tests (CRUD, auth, validation, pagination, and 404 for project_id/check_id mismatch)
- [x] 7.7 Add check result controller tests (listing, pagination, auth, and 404 for project_id/check_id mismatch)
- [x] 7.8 Update openapi.json with new endpoints and schemas

## 8. Job Lifecycle Management

- [x] 8.1 Enqueue first Oban job when a check is created (unless paused)
- [x] 8.2 Enqueue job when a paused check is resumed (update paused: false)
- [x] 8.3 Cancel pending Oban jobs when a check is deleted
- [x] 8.4 Add startup recovery wiring in `FF.Application` to re-enqueue checks that have no pending jobs after Oban boots (recovery after restart)
- [x] 8.5 Add tests for job enqueue on create, resume, delete cancellation, and restart recovery
