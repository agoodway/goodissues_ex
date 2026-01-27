# admin-accounts Specification

## Purpose
TBD - created by archiving change add-admin-accounts-ui. Update Purpose after archive.
## Requirements
### Requirement: Account List View
The admin interface SHALL provide a list view of all accounts in the system.

#### Scenario: Display account list
- **WHEN** an authenticated admin accesses `/admin/accounts`
- **THEN** a paginated list of accounts is displayed
- **AND** each account shows: id, name, email, status, created_at
- **AND** the list is sorted by creation date (newest first)

#### Scenario: Search accounts
- **WHEN** an admin enters a search term in the search box
- **THEN** the account list is filtered to show matching accounts
- **AND** search matches against: name, email
- **AND** pagination updates to reflect filtered results

#### Scenario: Filter by status
- **WHEN** an admin selects a status filter (active, inactive, all)
- **THEN** the account list is filtered to show only matching accounts
- **AND** pagination updates to reflect filtered results

### Requirement: Account Detail View
The admin interface SHALL provide a detail view for individual accounts.

#### Scenario: View account details
- **WHEN** an admin clicks on an account in the list view
- **THEN** the account detail page is displayed
- **AND** all account fields are shown: id, name, email, status, role, created_at, updated_at
- **AND** account statistics are displayed if available

#### Scenario: View account activity
- **WHEN** an admin views an account detail page
- **THEN** a list of recent account activities is displayed
- **AND** activities include: login events, profile changes, role changes
- **AND** activities are shown with timestamp and description

### Requirement: Account Creation
The admin interface SHALL allow admins to create new accounts.

#### Scenario: Create account with valid data
- **WHEN** an admin submits a valid account creation form
- **THEN** the account is created in the database
- **AND** the admin is redirected to the account detail page
- **AND** a success message is displayed
- **AND** an audit log entry is created

#### Scenario: Create account with invalid data
- **WHEN** an admin submits an invalid account creation form
- **THEN** the form is redisplayed with error messages
- **AND** the account is not created
- **AND** form fields retain entered values

### Requirement: Account Updates
The admin interface SHALL allow admins to update existing accounts.

#### Scenario: Update account with valid data
- **WHEN** an admin submits a valid account update form
- **THEN** the account is updated in the database
- **AND** the admin is redirected to the account detail page
- **AND** a success message is displayed
- **AND** an audit log entry is created

#### Scenario: Update account with invalid data
- **WHEN** an admin submits an invalid account update form
- **THEN** the form is redisplayed with error messages
- **AND** the account is not modified
- **AND** form fields retain entered values

### Requirement: Account Deactivation
The admin interface SHALL allow admins to deactivate and reactivate accounts.

#### Scenario: Deactivate account
- **WHEN** an admin clicks the deactivate button on an account
- **THEN** a confirmation dialog is displayed
- **WHEN** the admin confirms the deactivation
- **THEN** the account status is set to inactive
- **AND** the account cannot authenticate
- **AND** an audit log entry is created
- **AND** a success message is displayed

#### Scenario: Reactivate account
- **WHEN** an admin clicks the activate button on an inactive account
- **THEN** the account status is set to active
- **AND** the account can authenticate again
- **AND** an audit log entry is created
- **AND** a success message is displayed

### Requirement: Admin Authentication
The admin interface SHALL only be accessible to authenticated admin users.

#### Scenario: Unauthenticated access attempt
- **WHEN** an unauthenticated user attempts to access any `/admin/*` route
- **THEN** they are redirected to the login page
- **AND** an error message is displayed

#### Scenario: Non-admin access attempt
- **WHEN** a non-admin authenticated user attempts to access `/admin/*` routes
- **THEN** they are redirected to the home page
- **AND** a "permission denied" error message is displayed

### Requirement: Account Role Management
The admin interface SHALL allow admins to manage account roles.

#### Scenario: Change account role
- **WHEN** an admin changes an account's role
- **THEN** the role is updated in the database
- **AND** the account's permissions are updated
- **AND** an audit log entry is created
- **AND** a success message is displayed

#### Scenario: Role validation
- **WHEN** an admin attempts to assign an invalid role
- **THEN** the update is rejected
- **AND** an error message is displayed

