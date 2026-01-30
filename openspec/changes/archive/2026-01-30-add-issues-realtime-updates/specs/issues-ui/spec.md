## ADDED Requirements

### Requirement: Issue List View
The dashboard SHALL provide a list view of all issues within the current account with realtime updates when issues are created or modified.

#### Scenario: Display issue list
- **WHEN** an authenticated user accesses `/dashboard/:account_slug/issues`
- **THEN** a paginated list of issues is displayed
- **AND** each issue shows: status indicator, title, type badge, priority badge, project name, created date
- **AND** the list is sorted by creation date (newest first)
- **AND** the LiveView subscribes to realtime issue events for the account

#### Scenario: Realtime issue creation
- **GIVEN** a user is viewing the issues list page
- **WHEN** an issue is created via the API or another admin session
- **THEN** a toast notification appears indicating a new issue was created
- **AND** the total issue count in the header is incremented
- **AND** the issue appears in the list if it matches current filters and is within pagination range
- **AND** no page refresh is required

#### Scenario: Realtime issue update
- **GIVEN** a user is viewing the issues list page
- **WHEN** an issue displayed in the list is updated via the API or another admin session
- **THEN** the issue's information in the list is updated immediately
- **AND** if the status change causes the issue to no longer match current filters, it is removed from the list
- **AND** no page refresh is required

#### Scenario: Realtime update with pagination
- **GIVEN** a user is viewing page 2 of the issues list (issues 21-40)
- **WHEN** a new issue is created
- **THEN** a toast notification appears
- **AND** the issue does not appear on page 2
- **AND** the total count is incremented
- **AND** navigation to page 1 will show the new issue

#### Scenario: Realtime update with active filters
- **GIVEN** a user has filtered the issues list by status="new"
- **WHEN** an issue is created with status="in_progress"
- **THEN** a toast notification appears
- **AND** the issue does not appear in the filtered list
- **AND** the total count is incremented
- **WHEN** the user clears the status filter
- **THEN** the issue appears in the full list

#### Scenario: Pagination
- **WHEN** more than 20 issues match the current criteria
- **THEN** pagination controls are displayed
- **AND** users can navigate between pages

#### Scenario: Empty state
- **WHEN** no issues exist in the account
- **THEN** an empty state message is displayed

### Requirement: Dashboard Navigation
The dashboard sidebar SHALL include a link to the issues list.

#### Scenario: Issues navigation link
- **WHEN** viewing any dashboard page
- **THEN** the sidebar includes an "Issues" link under the Workspace section
- **AND** clicking the link navigates to `/dashboard/:account_slug/issues`

### Requirement: Issue Events Broadcasting
The system SHALL broadcast issue creation and update events to subscribed LiveViews using Phoenix PubSub.

#### Scenario: Broadcast on issue creation
- **GIVEN** an issue is successfully created via API or admin
- **WHEN** the issue is inserted into the database
- **THEN** a PubSub message is broadcast to the topic `"issues:account:<account_id>"`
- **AND** the message has type `:issue_created`
- **AND** the message payload includes: id, project_id, title, status, type, priority, number, inserted_at, and project details

#### Scenario: Broadcast on issue update
- **GIVEN** an issue is successfully updated via API or admin
- **WHEN** the issue is updated in the database
- **THEN** a PubSub message is broadcast to the topic `"issues:account:<account_id>"`
- **AND** the message has type `:issue_updated`
- **AND** the message payload includes: id, title, status, type, priority, and updated_at

#### Scenario: Account-scoped topics
- **GIVEN** multiple accounts exist in the system
- **WHEN** an issue is created or updated in account A
- **THEN** only users subscribed to `"issues:account:<account_a_id>"` receive the event
- **AND** users subscribed to other account topics do not receive the event
