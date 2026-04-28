## Context

FruitFly currently tracks bugs and errors reactively — issues are created by users or the error tracking pipeline. There is no proactive monitoring. The system already has Oban (v2.20.3) for background jobs and Req for HTTP requests, so the infrastructure for running checks exists.

Checks will be a new domain (`App.Monitoring`) alongside the existing `App.Tracking` context. The key integration point is auto-creating issues in `App.Tracking` when checks fail, using a system bot user as the submitter.

## Goals / Non-Goals

**Goals:**
- Users can configure HTTP checks against URLs, scoped to projects
- Checks run at configurable intervals using self-rescheduling Oban workers
- Check results are stored as an append-only log with status, response time, and errors
- Failed checks auto-create incident issues after a configurable failure threshold
- Recovered checks auto-archive their incident issues
- Flapping checks reopen recent incidents instead of creating duplicates (configurable window)
- REST API for full CRUD on checks and read access to check results

**Non-Goals:**
- Multi-region checking (single-origin only)
- Public status pages
- Non-HTTP checks (TCP, DNS, ICMP)
- Alerting beyond issue creation (no email/Slack/webhook notifications)
- Check result aggregation or uptime percentage calculations
- Dashboard UI for checks (API-only for this change)

## Decisions

### 1. New `App.Monitoring` Context

**Decision**: Create a separate `App.Monitoring` context rather than extending `App.Tracking`.

**Rationale**: Checks and check results are a distinct domain from issues and projects. The monitoring context calls into tracking (to create issues) but has its own lifecycle, schemas, and business rules. This keeps `App.Tracking` focused on issue management.

**Alternative considered**: Adding checks to `App.Tracking` — rejected because it would bloat an already large context and conflate monitoring config with issue tracking.

### 2. Self-Rescheduling Oban Workers

**Decision**: Use the self-rescheduling worker pattern instead of Oban Pro's DynamicCron.

**Rationale**: Each check has its own interval (30s to 3600s). A self-rescheduling worker reads the interval from the check record at execution time, so interval changes take effect on the next run without any cron reconfiguration. Oban Pro is not a dependency.

**Pattern**:
- Creating a check inserts the first Oban job
- Each job execution schedules the next before running the check
- Pausing a check skips rescheduling
- Deleting a check cancels pending jobs
- `unique` constraint on `check_id` prevents duplicate chains after restarts

### 3. Incident Issue Lifecycle

**Decision**: Checks create issues with type `:incident`, auto-archive on recovery, and reopen within a configurable time window.

**Rationale**: The user wants tight integration between monitoring and issue tracking. Using `:incident` as a distinct type lets the UI and API filter monitoring-generated issues from manually-created bugs and feature requests.

**Lifecycle**:
1. Check fails N consecutive times (N = `failure_threshold`, default 1)
2. System looks for an open incident issue for this check → if found, skip
3. System looks for a closed incident within `reopen_window_hours` (default 24) → if found, reopen (set status to `:in_progress`)
4. Otherwise, create a new incident issue via `App.Tracking.create_issue/3`
5. On recovery: find open incident issue, archive it

**Issue-to-check linking**: Store `check_id` and `issue_id` on `check_results` to trace which result triggered or reopened an incident. Also store `current_issue_id` on the check itself for quick lookup of the active incident.

### 4. System Bot User

**Decision**: Lazily create one bot user per account with a deterministic email (`bot@{account_id}.fruitfly.internal`) and no password.

**Rationale**: `create_issue/3` requires a user as submitter. A passwordless user with a non-routable email domain is simple, can't log in, and doesn't consume a real user seat. Lazy creation avoids a migration to seed existing accounts.

**Alternative considered**: Making `submitter_id` optional — rejected because it would require changes across the issue display layer and breaks the audit trail.

### 5. HTTP Client: Req

**Decision**: Use Req (already a dependency) for executing checks.

**Rationale**: Req is the project's standard HTTP client per AGENTS.md. It supports configurable timeouts, follows redirects, and returns structured responses.

### 6. Check Results Retention

**Decision**: No automatic pruning in this change. Check results accumulate indefinitely.

**Rationale**: Retention policies add complexity (another Oban job, configuration surface). Ship without it, add pruning when storage becomes an issue.

### 7. API Nesting

**Decision**: Checks and check results are fully nested under projects (`/api/v1/projects/:project_id/checks`, `/api/v1/projects/:project_id/checks/:check_id`, and `/api/v1/projects/:project_id/checks/:check_id/results`).

**Rationale**: Checks belong to projects, so nesting is natural for create, list, show, update, delete, and results operations. Including `project_id` on all routes makes project scoping explicit and avoids fetching checks or results outside their project context.

## Risks / Trade-offs

- **[Job duplication on restart]** → Mitigated by Oban's `unique` option keyed on `check_id` with a period matching the check interval. On app restart, the recovery process re-enqueues any checks that don't have a pending job.
- **[Check volume scaling]** → A single Oban queue with default concurrency may bottleneck with many checks. Mitigated by using a dedicated `:checks` queue with configurable concurrency. Not a concern at current scale.
- **[Bot user visibility]** → Bot users appear in user lists. Mitigated by filtering on the `.fruitfly.internal` email domain where needed. Acceptable for now.
- **[No check result pruning]** → `check_results` table will grow unbounded. Acceptable for MVP; add a pruning job in a follow-up change.
- **[Cross-context coupling]** → `App.Monitoring` calls `App.Tracking.create_issue/3` directly. This is a conscious trade-off — event-based decoupling would add complexity without clear benefit at this scale.
