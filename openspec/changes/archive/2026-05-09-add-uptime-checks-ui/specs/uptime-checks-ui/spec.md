## ADDED Requirements

### Requirement: Checks status board index page
The system SHALL display a realtime status board of all uptime checks for a project at `/dashboard/:account_slug/projects/:project_id/checks`. The page SHALL show each check's name, URL, current status (up/down/unknown/paused), interval, and last checked time. The list SHALL update in realtime via PubSub when checks are created, updated, deleted, or complete a run.

#### Scenario: User views checks for a project
- **WHEN** user navigates to the checks index page for a project
- **THEN** the system displays all checks belonging to that project with name, URL, status indicator, interval, and last checked time, ordered by name

#### Scenario: Check status updates in realtime
- **WHEN** a check completes a run and its status changes
- **THEN** the check row on the index page updates in-place without a page reload, reflecting the new status, last checked time, and consecutive failure count

#### Scenario: New check appears in realtime
- **WHEN** another user creates a check for the same project
- **THEN** the new check appears in the list without a page reload

#### Scenario: Deleted check disappears in realtime
- **WHEN** a check is deleted
- **THEN** the check row disappears from the list without a page reload

#### Scenario: Empty state
- **WHEN** a project has no checks
- **THEN** the system displays an empty state
- **AND** users with manage permission see a prompt to create the first check

#### Scenario: Non-manager sees view-only empty state
- **WHEN** a user without manage permission views a project with no checks
- **THEN** the system displays an empty state without check creation actions

### Requirement: Pause and resume checks inline
The system SHALL provide a pause/resume toggle button on each check row in the status board. Pausing a check SHALL prevent it from running. Resuming SHALL re-enqueue the Oban worker. The toggle SHALL be visible to users with manage permission only.

#### Scenario: User pauses a running check
- **WHEN** user clicks the pause button on an active check
- **THEN** the check's paused field is set to true, the row updates to show a "PAUSED" badge, and the check stops executing on its next scheduled run

#### Scenario: User resumes a paused check
- **WHEN** user clicks the resume button on a paused check
- **THEN** the check's paused field is set to false, the Oban worker is re-enqueued, and the row updates to show the check's actual status

#### Scenario: Pause/resume updates other connected clients
- **WHEN** a user pauses or resumes a check
- **THEN** all other users viewing the same project's checks index see the status change in realtime via PubSub

### Requirement: Create check with progressive disclosure
The system SHALL provide a check creation page at `/dashboard/:account_slug/projects/:project_id/checks/new` with a form that uses progressive disclosure. Basic fields (name, URL, method, interval) SHALL be visible by default. Advanced fields (expected status, keyword, keyword absence, failure threshold, reopen window hours, start paused) SHALL be in a collapsible section.

#### Scenario: User creates a check with basic fields only
- **WHEN** user fills in name, URL, and submits the form without expanding advanced settings
- **THEN** the check is created with default values for advanced fields (expected_status=200, failure_threshold=1, reopen_window_hours=24, paused=false) and user is redirected to the checks index

#### Scenario: User creates a check with advanced settings
- **WHEN** user expands the advanced settings section and configures keyword matching, failure threshold, and start paused
- **THEN** the check is created with all specified values

#### Scenario: Validation errors display inline
- **WHEN** user submits the form with invalid data (e.g., missing name, invalid URL)
- **THEN** the form displays validation errors inline without losing entered data

### Requirement: Check detail page with configuration and results
The system SHALL provide a check detail page at `/dashboard/:account_slug/projects/:project_id/checks/:id` showing the check's full configuration and a paginated, filterable list of check results.

#### Scenario: User views check detail
- **WHEN** user clicks on a check from the status board
- **THEN** the system displays the check's name, URL, method, status, interval, expected status, keyword settings, failure threshold, reopen window, pause state, created time, and last checked time

#### Scenario: User views check results
- **WHEN** user is on the check detail page
- **THEN** the system displays a paginated list of check results in reverse chronological order, showing status (up/down), HTTP status code, response time in ms, error message (if any), and timestamp

#### Scenario: User filters check results by status
- **WHEN** user selects a status filter (all, up, or down)
- **THEN** the results list updates to show only results matching the selected status, with pagination reset to page 1

#### Scenario: User paginates through results
- **WHEN** check has more results than fit on one page
- **THEN** the system displays pagination controls and the user can navigate between pages

### Requirement: Edit check via modal
The system SHALL provide a modal for editing a check's configuration, accessible from the check detail page at `/dashboard/:account_slug/projects/:project_id/checks/:id/edit`. The modal SHALL use the same progressive disclosure layout as the creation form.

#### Scenario: User edits a check
- **WHEN** user clicks edit on the check detail page
- **THEN** a modal appears pre-filled with the check's current values, and the user can modify fields and save

#### Scenario: User saves valid changes
- **WHEN** user modifies check fields and submits
- **THEN** the check is updated, the modal closes, and the detail page reflects the new values

#### Scenario: Edit validation errors
- **WHEN** user submits invalid changes in the edit modal
- **THEN** validation errors display inline within the modal without closing it

### Requirement: Delete check with confirmation
The system SHALL allow users with manage permission to delete a check from the check detail page. Deletion SHALL require confirmation.

#### Scenario: User deletes a check
- **WHEN** user clicks delete and confirms the action
- **THEN** the check and its pending Oban jobs are deleted, and the user is redirected to the checks index page

#### Scenario: User cancels deletion
- **WHEN** user clicks delete but cancels the confirmation
- **THEN** the check is not deleted and the user remains on the detail page

### Requirement: Project show page checks sidebar card
The system SHALL display a "Monitoring" card in the project show page sidebar showing the total check count, a status summary, and a link to the checks index page.

#### Scenario: Project with checks
- **WHEN** user views a project that has uptime checks
- **THEN** the sidebar shows a monitoring card with the count of checks and a status summary (e.g., "3 up, 1 down") and a link to the checks index

#### Scenario: Project with paused or unknown checks
- **WHEN** user views a project with paused or never-run checks
- **THEN** the sidebar summary includes non-zero paused and unknown counts instead of collapsing them into up/down totals

#### Scenario: Manager views project with no checks
- **WHEN** a user with manage permission views a project that has no uptime checks
- **THEN** the sidebar shows a monitoring card with "0 checks", a link to the checks index, and a link to create the first check

#### Scenario: Non-manager views project with no checks
- **WHEN** a user without manage permission views a project that has no uptime checks
- **THEN** the sidebar shows a monitoring card with "0 checks" and a link to the checks index without a create action

### Requirement: Authorization for check management
Only users with manage permission on the account SHALL be able to create, edit, delete, or pause/resume checks. All authenticated users with account access SHALL be able to view checks and results.

#### Scenario: Non-manager views checks
- **WHEN** a user without manage permission views the checks index or detail page
- **THEN** create, edit, delete, and pause/resume actions are hidden

#### Scenario: Non-manager attempts check mutation
- **WHEN** a user without manage permission attempts to create, edit, delete, or pause/resume a check
- **THEN** the system denies the action with a permission error

### Requirement: Breadcrumb navigation for check pages
All check pages SHALL display breadcrumb navigation showing the path: Projects → [Project Prefix] → Checks (→ [Check Name] for detail pages).

#### Scenario: Checks index breadcrumb
- **WHEN** user is on the checks index page
- **THEN** breadcrumb shows "Projects / [Project Prefix] / Checks" with links to projects list and project detail

#### Scenario: Check detail breadcrumb
- **WHEN** user is on a check detail page
- **THEN** breadcrumb shows "Projects / [Project Prefix] / Checks / [Check Name]" with links to projects list, project detail, and checks index
