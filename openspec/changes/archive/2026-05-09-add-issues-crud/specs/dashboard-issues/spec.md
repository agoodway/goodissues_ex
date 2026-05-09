## ADDED Requirements

### Requirement: Issue Detail View
The dashboard SHALL provide a detail view for individual issues.

#### Scenario: View issue details
- **WHEN** a user clicks on an issue in the list view
- **THEN** the issue detail page is displayed at `/dashboard/:account_slug/issues/:id`
- **AND** all issue fields are shown: title, description, status, type, priority, project, submitter email, created date, updated date

#### Scenario: Access non-existent issue
- **WHEN** a user accesses an issue that doesn't exist
- **THEN** a 404 error is displayed
- **AND** the user can navigate back to the issues list

#### Scenario: Access issue from another account
- **WHEN** a user attempts to access an issue belonging to a different account
- **THEN** a 404 error is displayed

### Requirement: Issue Creation
The dashboard SHALL allow authorized users to create new issues.

#### Scenario: Create issue with valid data
- **WHEN** an authorized user submits a valid issue creation form
- **THEN** the issue is created in the database
- **AND** the user is redirected to the issue detail page
- **AND** a success message is displayed

#### Scenario: Create issue with invalid data
- **WHEN** a user submits an invalid issue creation form
- **THEN** the form is redisplayed with error messages
- **AND** the issue is not created
- **AND** form fields retain entered values

#### Scenario: Project selection
- **WHEN** creating a new issue
- **THEN** a dropdown shows all projects in the current account
- **AND** project selection is required

### Requirement: Issue Updates
The dashboard SHALL allow authorized users to update existing issues.

#### Scenario: Update issue with valid data
- **WHEN** an authorized user submits a valid issue update form
- **THEN** the issue is updated in the database
- **AND** a success message is displayed
- **AND** the updated issue details are shown

#### Scenario: Update issue with invalid data
- **WHEN** a user submits an invalid issue update form
- **THEN** the form is redisplayed with error messages
- **AND** the issue is not modified

#### Scenario: Change issue status
- **WHEN** an authorized user changes an issue's status
- **THEN** the status is updated
- **AND** if status changes to archived, archived_at is set
- **AND** if status changes from archived, archived_at is cleared

### Requirement: Issue Deletion
The dashboard SHALL allow authorized users to delete issues.

#### Scenario: Delete issue
- **WHEN** an authorized user clicks the delete button on an issue
- **THEN** a confirmation dialog is displayed
- **WHEN** the user confirms the deletion
- **THEN** the issue is deleted from the database
- **AND** the user is redirected to the issues list
- **AND** a success message is displayed

#### Scenario: Cancel deletion
- **WHEN** a user cancels the deletion confirmation
- **THEN** the issue is not deleted
- **AND** the user remains on the current page
