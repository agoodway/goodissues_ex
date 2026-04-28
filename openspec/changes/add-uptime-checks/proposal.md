## Why

FruitFly tracks bugs and errors after they happen. Adding uptime checks lets users detect outages proactively — before users report them. When a check fails, FruitFly auto-creates an incident issue, connecting monitoring directly to the existing issue tracking workflow.

## What Changes

- New `Check` resource scoped to projects — configurable HTTP endpoint monitors with customizable intervals, expected status codes, and keyword matching
- New `CheckResult` append-only log recording each check execution (status, response time, status code, errors)
- Self-rescheduling Oban workers to run checks at per-check intervals without Oban Pro
- Automatic incident issue creation when consecutive failures cross a configurable threshold (default: 1)
- Automatic issue archival on recovery; reopening within a configurable window (default: 24 hours) instead of creating duplicate incidents
- System bot user per account to serve as submitter for auto-created issues
- New `:incident` issue type alongside existing `:bug` and `:feature_request`
- REST API endpoints for checks CRUD and check results retrieval

## Capabilities

### New Capabilities

- `uptime-checks`: Check configuration, scheduling, execution, and result storage
- `incident-lifecycle`: Automatic issue creation on failure, archival on recovery, and reopening within a configurable time window
- `bot-user`: System bot user per account for automated actions

### Modified Capabilities

- `issues`: Adding `:incident` to issue type enum
- `issues-ui`: Displaying and filtering `:incident` issues in existing dashboard issue views

## Impact

- **Database**: New `checks` and `check_results` tables
- **Schemas**: New `Check` and `CheckResult` Ecto schemas; updated `Issue` type enum
- **Contexts**: New `App.Monitoring` context; minor updates to `App.Tracking` and `App.Accounts` for incident type and bot user creation
- **API**: New check endpoints under `/api/v1/projects/:project_id/checks` (including show/update/delete member routes) and results under `/api/v1/projects/:project_id/checks/:check_id/results`
- **Auth**: Add `checks:read` and `checks:write` API key scopes
- **UI**: Update existing dashboard issue views to display and filter `:incident` issues
- **Dependencies**: Oban already present (v2.20.3); reuse Req for executing checks
- **OpenAPI**: Spec updates for new endpoints and schemas
