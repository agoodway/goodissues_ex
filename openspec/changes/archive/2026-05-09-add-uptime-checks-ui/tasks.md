## 1. PubSub Broadcasting

- [x] 1.1 Add `checks_topic/1` function to `GI.Monitoring` that returns `"checks:project:<project_id>"` topic string
- [x] 1.2 Add broadcast helpers to `GI.Monitoring` for `:check_created` and `:check_updated` flat check payloads, plus a `:check_deleted` payload containing the deleted check id
- [x] 1.3 Wire broadcasts into `create_check/3`, `update_check/2`, and `delete_check/1`
- [x] 1.4 Add `:check_run_completed` broadcast to `CheckRunner` after `apply_outcome` with updated check payload
- [x] 1.5 Add tests for PubSub broadcasts on CRUD operations and check run completion

## 2. Monitoring Context Additions

- [x] 2.1 Add `count_checks_by_status/2` function to `GI.Monitoring` that returns `%{up: n, down: n, unknown: n, paused: n}` for a project scoped to an account
- [x] 2.2 Add `list_check_results/4` status filter support (accept optional `:status` filter in the filters map for `:up` or `:down`)
- [x] 2.3 Add tests for `count_checks_by_status/2` and filtered `list_check_results/4`
- [x] 2.4 Persist `status: :down` on failed check runs and add a regression test so dashboard status reflects outages accurately

## 3. Router and Navigation

- [x] 3.1 Add check routes to router under the dashboard live_session: `/projects/:project_id/checks` (index), `/projects/:project_id/checks/new` (new), `/projects/:project_id/checks/:id` (show), `/projects/:project_id/checks/:id/edit` (show, edit action)
- [x] 3.2 Use the existing `active_nav: :projects` assignment on check pages so the projects nav item stays highlighted

## 4. Checks Index Page (Status Board)

- [x] 4.1 Create `GIWeb.Dashboard.CheckLive.Index` LiveView module — mount loads project from URL param, verifies account ownership, subscribes to PubSub topic
- [x] 4.2 Implement status board render with check rows: status indicator (colored dot), name, URL (truncated), method badge, interval display, last checked relative time, pause/resume button
- [x] 4.3 Implement paused check row styling — dimmed row with "PAUSED" badge replacing status indicator
- [x] 4.4 Implement `handle_event("toggle_pause", ...)` for inline pause/resume toggle (manager permission check)
- [x] 4.5 Implement PubSub handlers: `handle_info({:check_created, ...})`, `{:check_updated, ...}`, `{:check_deleted, ...}`, `{:check_run_completed, ...}` to update assigns in-place
- [x] 4.6 Implement permission-aware empty state: managers see a create-first-check prompt, non-managers see a view-only empty state
- [x] 4.7 Implement breadcrumb navigation: Projects / [Prefix] / Checks
- [x] 4.8 Add mobile-responsive card layout (matching issues index pattern)
- [x] 4.9 Add LiveView tests for checks index: listing, empty state, realtime updates, pause/resume, permission gating

## 5. Check New Page

- [x] 5.1 Create `GIWeb.Dashboard.CheckLive.New` LiveView module — mount with permission check, initialize changeset
- [x] 5.2 Implement form with basic fields: name, URL, method (select), interval (number input with seconds label)
- [x] 5.3 Implement advanced settings collapsible section with `show_advanced` toggle: expected status, keyword, keyword absence checkbox, failure threshold, reopen window hours, start paused checkbox
- [x] 5.4 Implement `handle_event("validate", ...)` for live validation and `handle_event("save", ...)` for creation with redirect to checks index
- [x] 5.5 Implement breadcrumb navigation: Projects / [Prefix] / Checks / New
- [x] 5.6 Add LiveView tests for check creation: basic fields, advanced fields, validation errors, permission gating

## 6. Check Show Page

- [x] 6.1 Create `GIWeb.Dashboard.CheckLive.Show` LiveView module — mount loads check scoped to project and account, subscribes to PubSub for live status updates
- [x] 6.2 Implement header section: status indicator, name, URL, pause/resume button, edit button, delete button (manager-only actions)
- [x] 6.3 Implement configuration summary card: method, interval, expected status, keyword settings, failure threshold, reopen window, consecutive failures, created/last checked timestamps
- [x] 6.4 Implement delete with confirmation dialog, redirect to checks index on success
- [x] 6.5 Implement paginated check results list: status badge, HTTP status code, response time (ms), error message, timestamp — reverse chronological
- [x] 6.6 Implement results status filter (all/up/down) with URL-driven filtering via `handle_params`
- [x] 6.7 Implement pagination controls for results (matching issues index pagination pattern)
- [x] 6.8 Implement PubSub handler for live status updates on the show page
- [x] 6.9 Implement breadcrumb navigation: Projects / [Prefix] / Checks / [Check Name]
- [x] 6.10 Add LiveView tests for check show: config display, results listing, filtering, pagination, delete, permission gating

## 7. Check Edit Modal

- [x] 7.1 Implement edit modal on CheckLive.Show triggered by `:edit` live_action — pre-filled form with progressive disclosure matching the new page layout
- [x] 7.2 Implement `handle_event("validate", ...)` and `handle_event("save", ...)` for update with modal close and page refresh on success
- [x] 7.3 Add LiveView tests for edit modal: pre-fill, save, validation errors, cancel

## 8. Project Show Page Integration

- [x] 8.1 Add `count_checks_by_status` call to `ProjectLive.Show.load_project/2` and assign results
- [x] 8.2 Add "Monitoring" sidebar card to project show template: check count, status summary (including paused/unknown counts when present), link to checks index, and a create-first-check link only for managers when empty
- [x] 8.3 Add LiveView tests for the monitoring sidebar card on project show page
