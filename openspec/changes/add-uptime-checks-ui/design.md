## Context

The uptime checks backend is implemented: `FF.Monitoring` context with CRUD, `CheckRunner` Oban worker with self-rescheduling, `IncidentLifecycle` for auto-creating/reopening/archiving issues, and a REST API. There is no dashboard UI — checks are API-only.

The dashboard already has LiveView pages for issues, projects, API keys, and subscriptions. All follow a consistent pattern: `FFWeb.Dashboard.<Resource>Live.{Index,New,Show}` modules, nested under `/dashboard/:account_slug/`, using `FFWeb.Layouts.dashboard` with the industrial terminal aesthetic.

Checks are scoped to projects. The issues list is account-wide, but checks should be accessed from the project context since users think about monitoring per-project.

## Goals / Non-Goals

**Goals:**
- Realtime status board for checks nested under a project, with PubSub-driven live updates
- Check detail page with config display, edit modal, delete, and paginated/filterable check results
- Check creation with progressive disclosure (basic fields visible, advanced collapsed)
- Pause/resume as a first-class inline action on the status board
- Sidebar card on project show page linking to checks with count and status summary

**Non-Goals:**
- Uptime percentage calculations or SLA tracking
- Sparkline or chart visualizations of response times (table-only for results)
- Bulk operations on checks (pause all, delete multiple)
- Check result export
- Notification preferences UI (alerting is via issue creation only)

## Decisions

### 1. Routing: Nested Under Projects

**Decision**: Checks UI lives at `/dashboard/:account_slug/projects/:project_id/checks/*` with dedicated LiveView modules in `FFWeb.Dashboard.CheckLive`.

**Routes**:
```
/projects/:project_id/checks          → CheckLive.Index (:index)
/projects/:project_id/checks/new      → CheckLive.New (:new)
/projects/:project_id/checks/:id      → CheckLive.Show (:show)
/projects/:project_id/checks/:id/edit → CheckLive.Show (:edit)
```

**Rationale**: Checks belong to projects; nesting routes makes the ownership explicit. Users navigate to checks from the project detail page, so the project context is always available. This matches how the REST API nests checks under projects.

**Alternative considered**: Top-level `/checks` route with account-wide listing — rejected because the user chose project-scoped access during exploration.

### 2. Realtime Updates via PubSub

**Decision**: Add PubSub broadcasting to the `FF.Monitoring` context and `CheckRunner` worker. The checks index subscribes and updates rows in-place.

**Topic**: `"checks:project:<project_id>"`

**Events**:
- `{:check_created, check_payload}` — from `create_check/3`
- `{:check_updated, check_payload}` — from `update_check/2` (including pause/resume)
- `{:check_deleted, %{id: check_id}}` — from `delete_check/1`
- `{:check_run_completed, check_payload}` — from `CheckRunner` after each execution (status, last_checked_at, consecutive_failures change)

**Payload**: Flat map with id, name, url, method, status, paused, interval_seconds, last_checked_at, consecutive_failures, failure_threshold. Enough to update a row without re-querying.

**Rationale**: The issues list already uses PubSub for realtime updates (`FF.Tracking` broadcasts on `issues:account:<account_id>`). Following the same pattern keeps consistency. Project-scoped topics keep broadcast traffic targeted.

**Alternative considered**: Polling on a timer — rejected because PubSub is already the established pattern and gives instant updates.

### 3. Progressive Disclosure for Check Form

**Decision**: The new check form shows basic fields (name, URL, method, interval) by default. The project comes from the route context and is shown as context rather than a selectable field. Advanced settings (expected status, keyword matching, failure threshold, reopen window, start paused) are behind an expandable section.

**Rationale**: Most checks only need a name, URL, and interval. Advanced settings like keyword matching and failure thresholds have sensible defaults. Progressive disclosure keeps the form approachable while exposing full power when needed.

**Implementation**: A boolean `show_advanced` assign toggled by a click event. No JS required — just conditional rendering in the HEEx template.

### 4. Check Show Page Layout

**Decision**: The check show page has two sections:
1. **Header + config**: Status indicator, name, URL, pause/resume button, edit/delete actions, and a summary of all configuration fields
2. **Results list**: Paginated table of check results with status filter (all/up/down), showing status, HTTP code, response time, error message, and timestamp

**Rationale**: The check detail is the natural place to see execution history. Results are already available via `Monitoring.list_check_results/4` with pagination. Filtering by status lets users quickly find failures.

**Edit**: Uses a modal (triggered by the `:edit` live action), matching the project show page pattern.

### 5. Pause/Resume as Inline Action

**Decision**: Each check row on the index page has a pause/resume toggle button. Clicking it calls `Monitoring.update_check(check, %{paused: !check.paused})`, which broadcasts the update via PubSub so all connected clients see the change.

**Rationale**: Pause/resume is the most common operational action. Burying it in an edit form adds friction. An inline toggle matches the "status board" feel — like muting an alarm.

**Visual**: Paused checks get a muted/dimmed row style with a "PAUSED" badge replacing the status indicator.

### 6. Project Show Page: Sidebar Card

**Decision**: Add a "Monitoring" card to the project show page sidebar showing:
- Total check count
- Status summary (e.g., "3 up, 1 down", or "All clear" when all checks are up; paused and unknown counts are shown when non-zero)
- Link to the checks index page

**Rationale**: Lightweight entry point. No need for tabs or major refactoring of the project show page. The sidebar already has stats and details cards.

**Data**: Requires a new `Monitoring.count_checks_by_status/2` function that returns `%{up: n, down: n, unknown: n, paused: n}`.

### 7. Project Loading in Check LiveViews

**Decision**: Each check LiveView loads the project from `:project_id` URL param and verifies it belongs to the current account. Store project in assigns for breadcrumb navigation and context.

**Rationale**: Checks are scoped to projects, and the URL includes `project_id`. Loading and verifying the project ensures proper authorization and provides context for the breadcrumb trail (Projects → Project Prefix → Checks).

## Risks / Trade-offs

- **[Broadcast frequency]** → Active checks broadcast on every execution (every 30s–3600s per check). With many checks in one project, this could mean frequent messages. Mitigated: LiveView handles PubSub efficiently, and payloads are small flat maps. Not a concern until hundreds of checks per project.
- **[Project show page query overhead]** → The sidebar card requires a count query. Mitigated: `count_checks_by_status` is a single aggregation query, not a full table scan. Acceptable overhead.
- **[Form complexity]** → The check schema has many fields. Progressive disclosure helps but the advanced section still has 5+ fields. Acceptable for a power-user feature.
- **[No optimistic updates for pause/resume]** → The UI waits for the PubSub broadcast to reflect the change. This means a brief delay. Mitigated: Could add optimistic local assign update on the event handler before the broadcast arrives, but the PubSub round-trip is fast enough for MVP.
