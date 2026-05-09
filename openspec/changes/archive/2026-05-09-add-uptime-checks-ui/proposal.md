## Why

The uptime checks backend (context, schemas, Oban workers, REST API, incident lifecycle) is implemented but has no dashboard UI. Users must manage checks entirely via the API. Adding a LiveView UI for checks lets users create, configure, monitor, and manage uptime checks directly from the project dashboard — matching the existing UI patterns for issues and API keys.

## What Changes

- Add a realtime status board for checks nested under the project show page, accessible via a sidebar card
- Add check detail page with configuration display, edit/delete actions, and paginated check results
- Add check creation page with progressive disclosure (basic fields + expandable advanced settings)
- Add pause/resume as a first-class inline action on the status board
- Add PubSub broadcasting from the Monitoring context and CheckRunner so the status board updates in realtime
- Persist failed check runtime state as `down` so dashboard status stays accurate during outages
- Add a "Monitoring" sidebar card to the project show page showing check count and status summary

## Capabilities

### New Capabilities
- `uptime-checks-ui`: LiveView pages for managing uptime checks — status board index, detail/show with results, create form with progressive disclosure, edit modal, delete confirmation, and realtime updates via PubSub

### Modified Capabilities
- `uptime-checks`: Add project-scoped PubSub lifecycle broadcasts for dashboard consumers and persist failed runtime status as `down`

## Impact

- **LiveView**: New `CheckLive.Index`, `CheckLive.New`, `CheckLive.Show` modules under `GIWeb.Dashboard`
- **Router**: New nested routes under `/dashboard/:account_slug/projects/:project_id/checks`
- **Monitoring context**: Add PubSub broadcasts for check CRUD and runtime updates
- **CheckRunner worker**: Broadcast after each check execution and persist `:down` status on failures
- **Project show page**: Add Monitoring sidebar card with check count/status linking to checks index
- **Navigation**: Check pages reuse the existing `active_nav: :projects` highlighting
