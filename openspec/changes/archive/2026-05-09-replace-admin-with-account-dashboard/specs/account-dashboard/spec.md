# account-dashboard Specification

## Purpose
Define the account-scoped dashboard that replaces the global admin section. Users access the dashboard to manage accounts they belong to, with permissions based on their role within each account.

## MODIFIED Requirements

### Requirement: Dashboard Authentication
The dashboard SHALL be accessible to any authenticated user who belongs to at least one account.

#### Scenario: Unauthenticated access attempt
- **WHEN** an unauthenticated user attempts to access any `/dashboard/*` route
- **THEN** they are redirected to the login page
- **AND** an error message is displayed

#### Scenario: Authenticated user with no accounts
- **WHEN** an authenticated user with no account memberships accesses `/dashboard`
- **THEN** they see an empty state message
- **AND** instructions on how to join or create an account are displayed

#### Scenario: Authenticated user with accounts
- **WHEN** an authenticated user with account memberships accesses `/dashboard`
- **THEN** the dashboard loads with their selected account context
- **AND** the account switcher shows all their accounts

### Requirement: Account Selection
The dashboard SHALL allow users to select which account they are working with.

#### Scenario: First dashboard access
- **WHEN** a user accesses the dashboard for the first time
- **AND** they have not previously selected an account
- **THEN** their first account (alphabetically by name) is auto-selected
- **AND** the selected account is stored in session

#### Scenario: Return dashboard access
- **WHEN** a user returns to the dashboard
- **AND** they previously selected an account
- **THEN** the previously selected account is auto-loaded
- **AND** the account switcher shows current selection

#### Scenario: Account membership removed
- **WHEN** a user returns to the dashboard
- **AND** their previously selected account membership was removed
- **THEN** another account is auto-selected if available
- **AND** a notice is shown if no accounts remain

#### Scenario: Switch account
- **WHEN** a user selects a different account from the account switcher
- **THEN** the dashboard reloads with the new account context
- **AND** the selection is stored in session
- **AND** the URL remains at `/dashboard` (no account ID in URL)

### Requirement: Account Switcher UI
The dashboard SHALL provide an account switcher component in the navigation.

#### Scenario: Display account switcher
- **WHEN** the dashboard is displayed
- **THEN** the account switcher shows in the header/nav area
- **AND** the current account name is displayed
- **AND** a dropdown indicator is visible

#### Scenario: Open account dropdown
- **WHEN** a user clicks the account switcher
- **THEN** a dropdown shows all their accounts
- **AND** each account shows: name, role badge
- **AND** the current account is visually highlighted

#### Scenario: Single account user
- **WHEN** a user belongs to only one account
- **THEN** the account switcher still displays
- **AND** clicking it shows only the one account (for consistency)

## ADDED Requirements

### Requirement: Account View (Member)
Members SHALL have read-only access to account information.

#### Scenario: Member views account
- **WHEN** a member accesses `/dashboard/account`
- **THEN** account details are displayed: name, slug, status, created date
- **AND** no edit controls are visible
- **AND** account members are listed (read-only)

### Requirement: Account Management (Owner/Admin)
Owners and admins SHALL be able to manage account settings.

#### Scenario: Owner/admin views account
- **WHEN** an owner or admin accesses `/dashboard/account`
- **THEN** account details are displayed
- **AND** edit controls are visible
- **AND** member management controls are visible

#### Scenario: Update account with valid data
- **WHEN** an owner/admin submits a valid account update form
- **THEN** the account is updated in the database
- **AND** a success message is displayed

#### Scenario: Update account with invalid data
- **WHEN** an owner/admin submits an invalid account update form
- **THEN** the form is redisplayed with error messages
- **AND** the account is not modified

#### Scenario: Member attempts account update
- **WHEN** a member attempts to submit an account update (via direct POST)
- **THEN** the request is rejected
- **AND** a "permission denied" error is returned

### Requirement: Member Management
Owners and admins SHALL be able to manage account members.

#### Scenario: View member list
- **WHEN** an owner/admin accesses `/dashboard/members`
- **THEN** a list of account members is displayed
- **AND** each member shows: email, role, joined date

#### Scenario: Change member role
- **WHEN** an owner changes a member's role
- **THEN** the role is updated
- **AND** a success message is displayed

#### Scenario: Admin role change limitations
- **WHEN** an admin attempts to change roles
- **THEN** they can promote members to admin
- **AND** they cannot promote anyone to owner
- **AND** they cannot demote other admins or owners

#### Scenario: Remove member
- **WHEN** an owner/admin removes a member from the account
- **THEN** the membership is deleted
- **AND** the user loses access to the account
- **AND** a success message is displayed

#### Scenario: Owner cannot be removed
- **WHEN** someone attempts to remove the account owner
- **THEN** the request is rejected
- **AND** an error message explains owners cannot be removed

#### Scenario: Member views member list
- **WHEN** a member accesses `/dashboard/members`
- **THEN** they see the member list (read-only)
- **AND** no management controls are visible

## REMOVED Requirements

### Requirement: Global Admin Authentication (REMOVED)
~~The admin interface SHALL only be accessible to authenticated admin users.~~

Replaced by: Dashboard Authentication (account-membership based)

### Requirement: System-wide Account List (REMOVED)
~~The admin interface SHALL provide a list view of all accounts in the system.~~

Replaced by: Users see only their own accounts via the account switcher.

### Requirement: System-wide Account Creation (REMOVED)
~~The admin interface SHALL allow admins to create new accounts.~~

Account creation is out of scope for this change. Users access existing accounts.

## Cross-References
- `admin-accounts` spec: This spec supersedes the admin authentication requirements
- API key management remains scoped to AccountUser (no changes needed)
