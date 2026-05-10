## ADDED Requirements

### Requirement: Heartbeat status board index page
The system SHALL display a realtime status board of all heartbeat monitors for a project at `/dashboard/:account_slug/projects/:project_id/heartbeats`. The page SHALL show each heartbeat's name, effective display status (paused when `paused=true`, otherwise the persisted status of up/down/unknown), interval, grace period, and last ping time. The list SHALL update in realtime via PubSub when heartbeats are created, updated, deleted, or receive a ping that changes status.

#### Scenario: User views heartbeats for a project
- **WHEN** user navigates to the heartbeats index page for a project
- **THEN** the system displays all heartbeats belonging to that project with name, status indicator, interval, grace period, and last ping time

#### Scenario: Heartbeat status updates in realtime
- **WHEN** a heartbeat's status changes (e.g., from up to down after missed deadline)
- **THEN** the heartbeat row on the index page updates in-place without a page reload, reflecting the new status and last ping time

#### Scenario: New heartbeat appears in realtime
- **WHEN** another user creates a heartbeat for the same project
- **THEN** the new heartbeat appears in the list without a page reload

#### Scenario: Deleted heartbeat disappears in realtime
- **WHEN** a heartbeat is deleted
- **THEN** the heartbeat row disappears from the list without a page reload

#### Scenario: Empty state
- **WHEN** a project has no heartbeats
- **THEN** the system displays an empty state
- **AND** users with manage permission see a prompt to create the first heartbeat

#### Scenario: Non-manager sees view-only empty state
- **WHEN** a user without manage permission views a project with no heartbeats
- **THEN** the system displays an empty state without heartbeat creation actions

#### Scenario: Pagination
- **WHEN** a project has more heartbeats than fit on one page
- **THEN** the system displays pagination controls with page numbers and total count

### Requirement: Pause and resume heartbeats inline
The system SHALL provide a pause/resume toggle button on each heartbeat row in the status board. Pausing a heartbeat SHALL cancel its deadline job. Resuming SHALL reschedule the deadline job. The toggle SHALL be visible to users with manage permission only.

#### Scenario: User pauses an active heartbeat
- **WHEN** user clicks the pause button on an active heartbeat
- **THEN** the heartbeat's paused field is set to true, the row updates to show a "PAUSED" badge, and the deadline job is cancelled

#### Scenario: User resumes a paused heartbeat
- **WHEN** user clicks the resume button on a paused heartbeat
- **THEN** the heartbeat's paused field is set to false, the deadline job is rescheduled, and the row updates to show the heartbeat's actual status

#### Scenario: Pause/resume updates other connected clients
- **WHEN** a user pauses or resumes a heartbeat
- **THEN** all other users viewing the same project's heartbeats index see the status change in realtime via PubSub

### Requirement: Create heartbeat with progressive disclosure
The system SHALL provide a heartbeat creation page at `/dashboard/:account_slug/projects/:project_id/heartbeats/new` with a form that uses progressive disclosure. Basic fields (name, interval seconds) SHALL be visible by default. Advanced fields (grace seconds, failure threshold, reopen window hours, start paused) SHALL be in a collapsible section. The ping token SHALL be auto-generated on the backend.

#### Scenario: User creates a heartbeat with basic fields only
- **WHEN** user fills in name and interval and submits the form without expanding advanced settings
- **THEN** the heartbeat is created with default values for advanced fields (grace_seconds=0, failure_threshold=1, reopen_window_hours=24, paused=false) and user is redirected to the heartbeat show page

#### Scenario: User creates a heartbeat with advanced settings
- **WHEN** user expands the advanced settings section and configures grace seconds, failure threshold, and start paused
- **THEN** the heartbeat is created with all specified values

#### Scenario: Validation errors display inline
- **WHEN** user submits the form with invalid data (e.g., missing name, interval below 30)
- **THEN** the form displays validation errors inline without losing entered data

#### Scenario: Redirect to show page after creation
- **WHEN** a heartbeat is successfully created
- **THEN** the user is redirected to the heartbeat show page where the ping URL is displayed

### Requirement: Heartbeat detail page with ping URL reveal and history
The system SHALL provide a heartbeat detail page at `/dashboard/:account_slug/projects/:project_id/heartbeats/:id` showing the heartbeat's full configuration, a manager-only ping URL reveal action with click-to-copy, and a paginated, filterable list of ping history. The ping URL SHALL be fetched only through an explicit manager-only reveal capability and SHALL NOT change REST API read-response redaction semantics.

#### Scenario: User views heartbeat detail
- **WHEN** user clicks on a heartbeat from the status board
- **THEN** the system displays the heartbeat's name, status, interval, grace period, failure threshold, reopen window, pause state, consecutive failures, created time, and last ping time

#### Scenario: Manager reveals ping URL with copy button
- **WHEN** a user with manage permission views the heartbeat detail page
- **AND** user requests to reveal the ping URL
- **THEN** the system checks manage permission and displays a `POST` method label and the full ping URL (`/api/v1/projects/:project_id/heartbeats/:heartbeat_token/ping`) in a prominent card with a copy-to-clipboard button that copies only the URL

#### Scenario: Copy ping URL to clipboard
- **WHEN** user clicks the copy button next to the ping URL
- **THEN** the ping URL is copied to the clipboard and the button provides visual feedback (e.g., changes to a checkmark briefly)

#### Scenario: Non-manager cannot reveal ping URL
- **WHEN** a user without manage permission views the heartbeat detail page
- **THEN** the ping URL reveal action and card are not displayed

#### Scenario: Direct reveal attempt without manage permission
- **WHEN** a user without manage permission attempts to reveal a heartbeat ping URL directly
- **THEN** the system denies the action with a permission error and does not return token-bearing fields

#### Scenario: User views ping history
- **WHEN** user is on the heartbeat detail page
- **THEN** the system displays a paginated list of heartbeat pings in reverse chronological order, showing kind (ping/start/fail), duration in ms, exit code, and pinged at timestamp

#### Scenario: User filters ping history by kind
- **WHEN** user selects a kind filter (all, ping, start, or fail)
- **THEN** the ping history list updates to show only pings matching the selected kind, with pagination reset to page 1

#### Scenario: User paginates through ping history
- **WHEN** heartbeat has more pings than fit on one page
- **THEN** the system displays pagination controls and the user can navigate between pages

#### Scenario: Ping history updates in realtime
- **WHEN** a new ping is received for the viewed heartbeat
- **THEN** the ping appears at the top of the history list without a page reload (if on page 1 and matching the current filter)

### Requirement: Edit heartbeat via modal
The system SHALL provide a modal for editing a heartbeat's configuration, accessible from the heartbeat detail page at `/dashboard/:account_slug/projects/:project_id/heartbeats/:id/edit`. The modal SHALL use the same progressive disclosure layout as the creation form. The ping token SHALL NOT be editable.

#### Scenario: User edits a heartbeat
- **WHEN** user clicks edit on the heartbeat detail page
- **THEN** a modal appears pre-filled with the heartbeat's current values for name, interval, grace seconds, failure threshold, reopen window hours, and paused state

#### Scenario: User saves valid changes
- **WHEN** user modifies heartbeat fields and submits
- **THEN** the heartbeat is updated, the modal closes, and the detail page reflects the new values

#### Scenario: Edit validation errors
- **WHEN** user submits invalid changes in the edit modal
- **THEN** validation errors display inline within the modal without closing it

### Requirement: Delete heartbeat with confirmation
The system SHALL allow users with manage permission to delete a heartbeat from the heartbeat detail page. Deletion SHALL require confirmation.

#### Scenario: User deletes a heartbeat
- **WHEN** user clicks delete and confirms the action
- **THEN** the heartbeat, its pings, and pending deadline jobs are deleted, and the user is redirected to the heartbeats index page

#### Scenario: User cancels deletion
- **WHEN** user clicks delete but cancels the confirmation
- **THEN** the heartbeat is not deleted and the user remains on the detail page

### Requirement: Merged monitoring card on project show page
The existing "Monitoring" sidebar card on the project show page SHALL display heartbeat counts and status alongside the existing check counts. The card SHALL show separate rows for checks and heartbeats with their respective counts and status summaries, and links to view each.

#### Scenario: Project with checks and heartbeats
- **WHEN** user views a project that has both uptime checks and heartbeats
- **THEN** the monitoring card shows a row for checks with count and status summary, a row for heartbeats with count and status summary, and links to view each

#### Scenario: Project with heartbeats but no checks
- **WHEN** user views a project that has heartbeats but no checks
- **THEN** the monitoring card shows "0" for checks and the heartbeat count with status summary

#### Scenario: Manager views project with no heartbeats
- **WHEN** a user with manage permission views a project that has no heartbeats
- **THEN** the monitoring card shows "0" for heartbeats with a link to create the first heartbeat

#### Scenario: Non-manager views project with no heartbeats
- **WHEN** a user without manage permission views a project that has no heartbeats
- **THEN** the monitoring card shows "0" for heartbeats without a create action

### Requirement: Authorization for heartbeat management
Only users with manage permission on the account SHALL be able to create, edit, delete, or pause/resume heartbeats. All authenticated users with account access SHALL be able to view heartbeats and ping history (but not the ping token).

#### Scenario: Non-manager views heartbeats
- **WHEN** a user without manage permission views the heartbeats index or detail page
- **THEN** create, edit, delete, and pause/resume actions are hidden, and the ping URL is not displayed

#### Scenario: Non-manager attempts heartbeat mutation
- **WHEN** a user without manage permission attempts to create, edit, delete, or pause/resume a heartbeat
- **THEN** the system denies the action with a permission error

### Requirement: Breadcrumb navigation for heartbeat pages
All heartbeat pages SHALL display breadcrumb navigation showing the path: Projects → [Project Prefix] → Heartbeats (→ [Heartbeat Name] for detail pages).

#### Scenario: Heartbeats index breadcrumb
- **WHEN** user is on the heartbeats index page
- **THEN** breadcrumb shows "Projects / [Project Prefix] / Heartbeats" with links to projects list and project detail

#### Scenario: Heartbeat detail breadcrumb
- **WHEN** user is on a heartbeat detail page
- **THEN** breadcrumb shows "Projects / [Project Prefix] / Heartbeats / [Heartbeat Name]" with links to projects list, project detail, and heartbeats index
