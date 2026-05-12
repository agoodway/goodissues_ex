# Add Heartbeat UI

## Summary

Add a dashboard UI for managing heartbeat monitors within a project. Heartbeats are the inverse of uptime checks — external jobs ping GoodIssues to prove they're running, and the system creates incidents when pings stop arriving. The backend (schema, API, workers, incident lifecycle) is fully built; this change adds the LiveView dashboard layer following the same patterns as the existing checks UI.

## Motivation

Heartbeat monitors can only be managed via the REST API today. Users need a web interface to:
- Create, view, edit, and delete heartbeat monitors within a project
- See the ping URL with click-to-copy so they can configure their cron jobs
- View ping history to understand when jobs ran and whether they succeeded
- Pause/resume heartbeats during maintenance windows
- See heartbeat status alongside checks in the project overview

## Scope

### In Scope

1. **HeartbeatLive.Index**: List heartbeats for a project with status indicators, pause/resume toggle, and pagination. Columns: status, name, interval, grace, last ping. Real-time updates via PubSub.

2. **HeartbeatLive.New**: Create form with progressive disclosure. Basic fields: name, interval. Advanced: grace seconds, failure threshold, reopen window, start paused. Token is auto-generated on the backend; after create, redirect to show page where the ping URL is displayed.

3. **HeartbeatLive.Show**: Detail page with:
   - Manager-only ping URL reveal with click-to-copy (`/api/v1/projects/:project_id/heartbeats/:heartbeat_token/ping`, with `POST` shown separately)
   - Status, interval, grace, last ping metadata
   - Paginated ping history table (kind, duration, exit code, pinged at) with kind filter
   - Configuration sidebar (interval, grace, failure threshold, reopen window, consecutive failures)
   - Timeline sidebar (created, last ping)
   - Edit modal (name, interval, grace, failure threshold, reopen window, paused)
   - Delete with confirmation

4. **Router**: Four new live routes in the dashboard scope:
   - `/projects/:project_id/heartbeats` → Index
   - `/projects/:project_id/heartbeats/new` → New
   - `/projects/:project_id/heartbeats/:id` → Show
   - `/projects/:project_id/heartbeats/:id/edit` → Show (edit action)

5. **Project show page**: Extend the existing Monitoring sidebar card to show heartbeat counts and status summary alongside checks. Add "View heartbeats" link and conditional "Create first heartbeat" link.

6. **Backend additions** (small, to support the UI):
    - `Monitoring.change_heartbeat/2` — changeset helper for LiveView forms
    - `Monitoring.heartbeats_topic/1` — PubSub topic for a project's heartbeats
    - Broadcast from `create_heartbeat`, `update_heartbeat`, `delete_heartbeat`, and ping receipt
    - `Monitoring.count_heartbeats_by_status/2` — for the project show page card
    - Manager-only ping URL reveal capability for the dashboard UI, without changing default REST read-response redaction

### Out of Scope
- Heartbeat ping URL variations (start, fail endpoints) in the UI — show only the main ping URL
- Alert rule configuration UI — alert_rules field exists but is an advanced feature for later
- Bulk operations on heartbeats
- Heartbeat-specific dashboard/analytics views
- CLI commands for heartbeats

## Dependencies

- `GI.Monitoring` context with full heartbeat CRUD and ping listing
- `GI.Monitoring.Heartbeat` and `GI.Monitoring.HeartbeatPing` schemas
- `GI.Monitoring.HeartbeatScheduler` for pause/resume side effects
- Existing checks UI as the pattern template (layout, components, PubSub approach)
- Dashboard layout with sidebar navigation
- `GIWeb.Layouts.dashboard` component

## Risks

- **Ping token exposure**: The show page can reveal the full ping token for users who need to configure jobs. It should only be available through an explicit manager-only reveal action. Mitigated by checking `Scope.can_manage_account?/1` before fetching or rendering the token, and by preserving redaction on normal management reads.

- **PubSub broadcast additions**: Adding broadcasts to existing context functions could affect performance if many heartbeats are active. Mitigated by scoping topics per project (same pattern as checks).

- **Copy-to-clipboard**: Reuses the existing `CopyToClipboard` JavaScript hook, which copies from an input referenced by `data-copy-target`. The heartbeat UI should follow that convention so clipboard behavior and visual feedback stay consistent with the API key UI.

## Alternatives Considered

1. **Combined checks + heartbeats list page**: Show both in one table with a type filter. Rejected because checks and heartbeats have different columns (URL/method vs ping token/grace) and different detail pages. Separate pages are clearer.

2. **Show ping token only at creation time**: Like many API key flows, show the secret once. Rejected because the ping token isn't truly secret (it's used in cron job URLs) and users frequently need to reference it when configuring new jobs.

3. **Top-level "Heartbeats" navigation item**: Give heartbeats their own sidebar section. Rejected in favor of nesting under projects (same as checks) since heartbeats are always scoped to a project.
