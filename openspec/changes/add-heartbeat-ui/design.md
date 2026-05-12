## Context

The heartbeat monitoring backend is fully implemented: schema, API controllers, ping endpoints, deadline workers, recovery workers, and incident lifecycle. What's missing is the LiveView dashboard layer.

The uptime checks UI (`check_live/index.ex`, `check_live/new.ex`, `check_live/show.ex`) was recently built and provides a proven pattern: PubSub-driven real-time updates, progressive disclosure forms, paginated history tables, edit modals, and authorization guards. The heartbeat UI follows this pattern closely with heartbeat-specific differences.

The `Monitoring` context already exposes all CRUD functions needed: `list_heartbeats/3`, `get_heartbeat/3`, `create_heartbeat/3`, `update_heartbeat/2`, `delete_heartbeat/1`, `list_heartbeat_pings/2`. A few small additions are needed to support LiveView forms and real-time updates.

## Goals / Non-Goals

**Goals:**
- Provide a full CRUD dashboard UI for heartbeat monitors nested under projects
- Display the ping URL prominently with click-to-copy so users can configure their external jobs
- Show paginated ping history with kind filtering on the detail page
- Real-time status updates via PubSub (same pattern as checks)
- Merge heartbeat status into the existing Monitoring card on the project show page

**Non-Goals:**
- Alert rule configuration UI (the `alert_rules` JSON field exists but is an advanced feature for later)
- Ping URL variations (start/fail endpoints) — only show the main `/ping` URL
- Heartbeat analytics or uptime percentage calculations
- CLI commands for heartbeats

## Decisions

### 1. Follow the checks UI pattern exactly

Mirror the three-page structure (`index`, `new`, `show`) with the same layout components, breadcrumb style, authorization checks, and PubSub approach. This keeps the codebase consistent and reduces review burden.

**Alternative considered:** A single-page CRUD interface with inline create/edit. Rejected because the checks UI already establishes the multi-page pattern and users will expect consistency between checks and heartbeats.

### 2. Ping URL with clipboard JS hook

The show page will display the full ping URL (`/api/v1/projects/:project_id/heartbeats/:heartbeat_token/ping`) in a prominent card with a separate `POST` method label and a copy-to-clipboard button. Reuse the existing Phoenix LiveView JS hook (`CopyToClipboard`), which calls `navigator.clipboard.writeText()`.

The existing hook receives the text to copy through a `data-copy-target` attribute that points to an input element containing the copyable URL. Extend the hook only if that convention is insufficient for the heartbeat layout.

**Alternative considered:** Using a hidden input with `document.execCommand('copy')`. Rejected because `navigator.clipboard` is the modern standard and supported in all target browsers.

### 3. Ping token reveal scoped to managers

Normal heartbeat management reads continue to redact token-bearing fields. The show page renders a manager-only reveal action; when clicked, it calls an explicit backend reveal capability that checks `can_manage` before returning the full ping URL. Read-only users see the heartbeat configuration and ping history but not the reveal action or token URL.

This preserves the canonical API behavior where post-create management reads redact the token while still giving managers a deliberate way to retrieve the URL when configuring cron jobs.

### 4. PubSub topic and broadcasts added to Monitoring context

Add `heartbeats_topic/1` returning `"heartbeats:project:#{project_id}"` and broadcast from:
- `create_heartbeat` → `:heartbeat_created`
- `update_heartbeat` → `:heartbeat_updated`
- `delete_heartbeat` → `:heartbeat_deleted`
- Ping receipt (in `record_heartbeat_ping` or equivalent) → `:heartbeat_ping_received`
- Runtime status changes from deadline and recovery paths (prefer centralizing in `update_heartbeat_runtime/2`) → `:heartbeat_updated`

This follows the exact pattern used by checks (`checks_topic/1`, `:check_created`, `:check_updated`, etc.). Heartbeat payloads include `id`, `name`, `status`, `paused`, `interval_seconds`, `grace_seconds`, `last_ping_at`, `next_due_at`, `consecutive_failures`, and `failure_threshold`. Ping payloads include `heartbeat_id`, `ping`, `status`, `last_ping_at`, `next_due_at`, and `paused` so the show page can prepend history while the index can update display state.

### 5. Merged Monitoring card on project show page

The existing "Monitoring" sidebar card on the project show page already shows check counts and status. Add heartbeat counts below the checks row using a new `count_heartbeats_by_status/2` context function that returns `%{up: n, down: n, unknown: n, paused: n}` (same shape as `count_checks_by_status/2`). Add "View heartbeats" and conditional "Create first heartbeat" links.

### 6. Ping history columns

The show page displays ping history in a table with columns: Kind (ping/start/fail badge), Duration (ms), Exit Code, and Pinged At. A kind filter dropdown allows filtering by ping type. This mirrors the check results table pattern but with heartbeat-specific fields.

### 7. `change_heartbeat/2` for LiveView forms

Add a `change_heartbeat/2` function to the Monitoring context, mirroring `change_check/2`. Routes to `create_changeset` for new structs and `update_changeset` for persisted ones.

## Risks / Trade-offs

- **Ping token exposure in DOM** → Only rendered for `can_manage` users. The token is already exposed in the API create response, so this is consistent. The URL is not more sensitive than the API key used to create it.

- **JS hook dependency for clipboard** → Clipboard API requires HTTPS in production (works on localhost for dev). If the hook fails, the URL is still visible and selectable for manual copy. Graceful degradation.

- **PubSub broadcast volume** → Heartbeats with short intervals (30s) will broadcast ping events frequently. Scoping topics per-project limits the blast radius. The index page handles `:heartbeat_ping_received` only when the payload changes display state such as status, last ping, next due, or paused state; the show page prepends matching ping events only for the viewed heartbeat.
