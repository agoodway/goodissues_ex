## ADDED Requirements

### Requirement: System Bot User

The system SHALL provide a bot user per account for automated actions. The bot user is lazily created on first use and has no password (cannot log in).

#### Scenario: Get or create bot user for account
- **WHEN** the system needs a bot user for an account
- **AND** no bot user exists for that account
- **THEN** a user is created with email "bot@{account_id}.goodissues.internal" and no hashed_password
- **AND** the user is added as a member of the account

#### Scenario: Get existing bot user
- **WHEN** the system needs a bot user for an account
- **AND** a bot user already exists (email matching "bot@{account_id}.goodissues.internal")
- **THEN** the existing user is returned without creating a new one

#### Scenario: Bot user cannot authenticate
- **WHEN** a login attempt is made with a bot user's email
- **THEN** authentication fails because the user has no password
