## ADDED Requirements

### Requirement: List API Keys
The system SHALL provide an admin interface to list all API keys in the system with filtering and search capabilities.

#### Scenario: List all API keys
- **GIVEN** an authenticated admin user
- **WHEN** the user navigates to the admin API keys index page
- **THEN** all API keys are displayed in a table format
- **AND** each row shows: name, type, owner, account, status, scopes, last_used_at, expires_at

#### Scenario: Filter API keys by status
- **GIVEN** an authenticated admin user on the API keys index page
- **WHEN** the user filters by status (active/revoked)
- **THEN** only API keys matching the selected status are displayed

#### Scenario: Filter API keys by type
- **GIVEN** an authenticated admin user on the API keys index page
- **WHEN** the user filters by type (public/private)
- **THEN** only API keys matching the selected type are displayed

#### Scenario: Search API keys
- **GIVEN** an authenticated admin user on the API keys index page
- **WHEN** the user searches by name or owner email
- **THEN** API keys matching the search criteria are displayed

### Requirement: View API Key Details
The system SHALL provide an admin interface to view detailed information about a specific API key.

#### Scenario: View API key details
- **GIVEN** an authenticated admin user
- **WHEN** the user clicks on an API key from the list
- **THEN** the API key details page is displayed
- **AND** the page shows: name, type, token_prefix, status, scopes, last_used_at, expires_at, created_at, updated_at, owner information, account information

#### Scenario: Display associated user and account
- **GIVEN** an authenticated admin user viewing an API key details page
- **WHEN** the page loads
- **THEN** the associated user (email, name) and account (name, slug) are displayed
- **AND** the user's role in the account is shown

### Requirement: Create API Key
The system SHALL provide an admin interface to create new API keys for any account_user.

#### Scenario: Create API key with minimal fields
- **GIVEN** an authenticated admin user
- **WHEN** the user creates an API key with name, account_user selection, and type
- **THEN** the API key is created successfully
- **AND** the full token is displayed once on the confirmation page
- **AND** the user is warned that the token cannot be retrieved later
- **AND** the user is redirected to the API key details page

#### Scenario: Create API key with scopes
- **GIVEN** an authenticated admin user creating an API key
- **WHEN** the user specifies one or more scopes
- **THEN** the API key is created with the specified scopes
- **AND** the scopes are displayed in the API key details

#### Scenario: Create API key with expiration
- **GIVEN** an authenticated admin user creating an API key
- **WHEN** the user sets an expires_at date
- **THEN** the API key is created with the specified expiration date
- **AND** the expiration date is displayed in the API key details

#### Scenario: Validate required fields on creation
- **GIVEN** an authenticated admin user creating an API key
- **WHEN** required fields (name, account_user, type) are missing
- **THEN** appropriate validation errors are displayed
- **AND** the API key is not created

### Requirement: Revoke API Key
The system SHALL provide an admin interface to revoke existing API keys.

#### Scenario: Revoke active API key
- **GIVEN** an authenticated admin user viewing an API key details page
- **WHEN** the user clicks the revoke button and confirms
- **THEN** the API key status is changed to revoked
- **AND** the key can no longer be used for authentication
- **AND** a success message is displayed

#### Scenario: Revoke with confirmation
- **GIVEN** an authenticated admin user attempting to revoke an API key
- **WHEN** the user clicks the revoke button
- **THEN** a confirmation modal is displayed
- **AND** the user must confirm before revocation occurs

#### Scenario: Cannot reuse revoked API key
- **GIVEN** an API key with revoked status
- **WHEN** a request is made using the revoked API key
- **THEN** the authentication fails
- **AND** an unauthorized error is returned

### Requirement: Admin Access Control
The system SHALL restrict API key management UI to admin users only.

#### Scenario: Non-admin user cannot access API keys UI
- **GIVEN** an authenticated non-admin user
- **WHEN** the user attempts to access any admin API key route
- **THEN** access is denied
- **AND** an unauthorized error is displayed

#### Scenario: Unauthenticated user cannot access API keys UI
- **GIVEN** an unauthenticated user
- **WHEN** the user attempts to access any admin API key route
- **THEN** the user is redirected to the login page

### Requirement: Display Token Once
The system SHALL display the full API token only once upon creation and never again.

#### Scenario: Token displayed on creation
- **GIVEN** an authenticated admin user creating an API key
- **WHEN** the API key is created successfully
- **THEN** the full token is displayed on the confirmation page
- **AND** a copy-to-clipboard button is provided

#### Scenario: Token not retrievable after creation
- **GIVEN** an API key that was previously created
- **WHEN** an admin views the API key details page
- **THEN** only the token prefix (first 12 characters) is displayed
- **AND** the full token is not shown anywhere in the UI

#### Scenario: Security warning on token display
- **GIVEN** an authenticated admin user viewing the generated token
- **WHEN** the token is displayed
- **THEN** a warning message indicates the token cannot be retrieved later
- **AND** the user is advised to copy and save it securely
