## ADDED Requirements

### Requirement: Issue List View
The dashboard SHALL provide a list view of all issues within the current account.

#### Scenario: Display issue list
- **WHEN** an authenticated user accesses `/dashboard/:account_slug/issues`
- **THEN** a paginated list of issues is displayed
- **AND** each issue shows: status indicator, title, type badge, priority badge, project name, created date
- **AND** the list is sorted by creation date (newest first)

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
