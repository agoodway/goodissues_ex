# dashboard-api-keys Specification

## ADDED Requirements

### Requirement: Edit API Key Scopes
The dashboard interface SHALL allow account owners and admins to edit API key scopes using checkboxes without recreating the key.

#### Scenario: Navigate to edit page
- **WHEN** an owner or admin clicks the edit button on an active API key show page
- **THEN** they are redirected to the edit page
- **AND** the current scopes are pre-selected as checkboxes
- **AND** all available scopes are displayed as checkboxes

#### Scenario: Edit scopes successfully
- **WHEN** an authorized user submits valid scope changes
- **THEN** the API key scopes are updated in the database
- **AND** the user is redirected to the API key show page
- **AND** a success flash message is displayed
- **AND** the updated scopes are visible on the show page
- **AND** all other API key attributes remain unchanged

#### Scenario: Select scopes via checkboxes
- **WHEN** a user checks or unchecks scope checkboxes
- **THEN** only the selected scopes are submitted
- **AND** previously selected checkboxes remain selected on form redisplay
- **AND** unselected checkboxes are cleared

#### Scenario: Save scope selection
- **WHEN** a user saves a new scope selection
- **THEN** the selected checkboxes are converted to an array of scope strings
- **AND** the array is saved to the API key scopes field
- **AND** the API key is updated with only the selected scopes

#### Scenario: Attempt to edit with unauthorized role
- **WHEN** a user with member role attempts to access the edit page
- **THEN** they are redirected to the API keys list page
- **AND** an error flash message is displayed
- **AND** the API key is not modified

#### Scenario: Attempt to edit revoked key
- **WHEN** a user attempts to edit a revoked API key
- **THEN** they are redirected to the API key show page
- **AND** an error flash message is displayed
- **AND** the API key status remains revoked

#### Scenario: Cancel edit
- **WHEN** a user clicks the cancel button on the edit page
- **THEN** they are redirected to the API key show page
- **AND** no changes are made to the API key
- **AND** no flash messages are displayed

#### Scenario: Edit button visibility
- **WHEN** viewing an active API key show page as owner or admin
- **THEN** an edit button is displayed
- **WHEN** viewing an API key show page as member
- **THEN** no edit button is displayed
- **WHEN** viewing a revoked API key show page
- **THEN** no edit button is displayed

#### Scenario: Empty scopes (no checkboxes selected)
- **WHEN** a user unchecks all scope checkboxes
- **THEN** the API key scopes are set to an empty array
- **AND** the key has no access restrictions (equivalent to "all scopes")
- **AND** a warning may be displayed about unrestricted access
