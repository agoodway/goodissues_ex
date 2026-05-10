## 1. Backend Additions

- [ ] 1.1 Add `change_heartbeat/2` to `Monitoring` context (mirrors `change_check/2` — routes to `create_changeset` for new, `update_changeset` for persisted)
- [ ] 1.2 Add `heartbeats_topic/1` to `Monitoring` context returning `"heartbeats:project:#{project_id}"`
- [ ] 1.3 Add PubSub broadcasts to `create_heartbeat`, `update_heartbeat`, `delete_heartbeat` (`:heartbeat_created`, `:heartbeat_updated`, `:heartbeat_deleted`)
- [ ] 1.4 Add PubSub broadcast for ping receipt (`:heartbeat_ping_received`) with heartbeat status update payload
- [ ] 1.5 Add `count_heartbeats_by_status/2` to `Monitoring` context returning `%{up: n, down: n, unknown: n, paused: n}`
- [ ] 1.6 Add `maybe_filter_ping_kind/2` support to `list_heartbeat_pings/2` for `kind=ping/start/fail/all` so LiveView filtering happens before pagination
- [ ] 1.7 Broadcast runtime heartbeat status changes from missed-deadline and recovery paths (prefer centralizing in `update_heartbeat_runtime/2`) so deadline-driven `up`/`down` transitions update connected LiveViews
- [ ] 1.8 Define heartbeat PubSub payload helpers: `heartbeat_payload/1` for list/detail updates and `heartbeat_ping_payload/2` for ping history prepends, including heartbeat id, ping, status, last ping, next due, paused, and deletion id where applicable
- [ ] 1.9 Add an explicit manager-only ping URL reveal capability for dashboard use that returns the full `/api/v1/projects/:project_id/heartbeats/:heartbeat_token/ping` URL without changing normal management read redaction

## 2. Clipboard JS Hook

- [ ] 2.1 Reuse the existing `CopyToClipboard` hook with its `data-copy-target` input convention; extend it only if needed while preserving existing behavior and visual feedback

## 3. HeartbeatLive.Index

- [ ] 3.1 Create `heartbeat_live/index.ex` with mount, handle_params, pagination, and PubSub subscription to `heartbeats_topic`
- [ ] 3.2 Add render with status board table (columns: status, name, interval, grace, last ping), mobile card layout, empty state, and pagination footer
- [ ] 3.3 Add pause/resume toggle event handler with `can_manage` guard
- [ ] 3.4 Add PubSub handlers for `:heartbeat_created`, `:heartbeat_updated`, `:heartbeat_deleted`, and `:heartbeat_ping_received`

## 4. HeartbeatLive.New

- [ ] 4.1 Create `heartbeat_live/new.ex` with mount, permission guard, form setup using `change_heartbeat(%Heartbeat{})`
- [ ] 4.2 Add render with progressive disclosure form (basic: name, interval; advanced: grace, failure threshold, reopen window, start paused)
- [ ] 4.3 Add validate and save event handlers; redirect to show page on success

## 5. HeartbeatLive.Show

- [ ] 5.1 Create `heartbeat_live/show.ex` with mount, PubSub subscription, and handle_params for `:show` and `:edit` actions
- [ ] 5.2 Add manager-only ping URL reveal card with copy-to-clipboard hook; do not fetch or render the token until a `can_manage` user requests reveal
- [ ] 5.3 Add ping history table with kind filter (all/ping/start/fail), pagination, and PubSub-driven prepend for new pings
- [ ] 5.4 Add configuration sidebar (interval, grace, failure threshold, reopen window, consecutive failures) and timeline sidebar (created, last ping)
- [ ] 5.5 Add edit modal with progressive disclosure form (name, interval, grace, failure threshold, reopen window, paused)
- [ ] 5.6 Add delete event handler with confirmation, pause/resume toggle, and PubSub handlers
- [ ] 5.7 Require event-level `can_manage` guards for `handle_params(:edit)`, `handle_event("save")`, `handle_event("delete")`, and `handle_event("toggle_pause")`

## 6. Router and Navigation

- [ ] 6.1 Add four live routes in dashboard scope: heartbeats index, new, show, show/edit
- [ ] 6.2 Update project show page to load heartbeat counts via `count_heartbeats_by_status/2` and display in merged Monitoring card with "View heartbeats" and conditional "Create first heartbeat" links
- [ ] 6.3 Add breadcrumb links for index, new, show, and edit states matching the dashboard project/checks pattern

## 7. Testing

- [ ] 7.1 Add tests for `change_heartbeat/2`, `heartbeats_topic/1`, `count_heartbeats_by_status/2`, and manager-only ping URL reveal behavior
- [ ] 7.2 Add context tests for `list_heartbeat_pings/2` kind filtering and heartbeat runtime/status broadcasts
- [ ] 7.3 Add LiveView tests for heartbeat index (list, empty state, pagination, pause/resume, `:heartbeat_ping_received` realtime updates)
- [ ] 7.4 Add LiveView tests for heartbeat new (create with defaults, create with advanced, validation errors, non-manager access denial)
- [ ] 7.5 Add LiveView tests for heartbeat show (detail display, edit modal, delete, manager-only ping URL reveal and copy behavior, non-manager reveal hiding, kind filter reset, pagination, realtime ping prepend)
- [ ] 7.6 Add LiveView tests for hidden manager-only controls and direct non-manager mutation attempts for create/edit/delete/pause-resume events
- [ ] 7.7 Add LiveView assertions for heartbeat breadcrumb links
- [ ] 7.8 Add LiveView test for project show page merged monitoring card with heartbeat counts
