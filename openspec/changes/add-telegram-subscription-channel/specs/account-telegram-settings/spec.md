## ADDED Requirements

### Requirement: Account Telegram profile storage
The system SHALL store at most one Telegram profile per account. A Telegram profile SHALL contain the owning account ID, an encrypted bot token, an optional bot username, and timestamps.

#### Scenario: Create Telegram profile for account
- **WHEN** an account admin saves a Telegram bot token and optional bot username
- **THEN** the system creates a Telegram profile scoped to that account
- **AND** the account cannot have a second Telegram profile

#### Scenario: Optional bot username
- **WHEN** an account admin saves a Telegram bot token without a bot username
- **THEN** the system stores the Telegram profile successfully

### Requirement: Telegram bot token encryption
The system SHALL encrypt Telegram bot tokens at rest using a Cloak-backed encrypted Ecto field. The plaintext bot token SHALL be accepted through a redacted virtual field and SHALL NOT be persisted directly.

#### Scenario: Token is encrypted on save
- **WHEN** a Telegram profile is inserted or updated with a plaintext bot token
- **THEN** the system stores the token in the encrypted token column
- **AND** the plaintext token is not stored in a plain database field

#### Scenario: Token decrypts for delivery
- **WHEN** the Telegram delivery worker loads a Telegram profile
- **THEN** the encrypted token field is available to the worker as the decrypted bot token value

### Requirement: Telegram profile management
The system SHALL allow authorized account managers to create, update, and delete the account Telegram profile. Unauthorized account users SHALL NOT be able to mutate Telegram profile settings.

#### Scenario: Authorized manager updates profile
- **WHEN** an account manager updates the bot token or bot username
- **THEN** the system persists the updated Telegram profile for the current account

#### Scenario: Unauthorized user cannot update profile
- **WHEN** an account user without account-management permission attempts to update Telegram settings
- **THEN** the system rejects the request and leaves the Telegram profile unchanged

#### Scenario: Delete Telegram profile
- **WHEN** an account manager deletes the Telegram profile
- **THEN** the system removes the account Telegram profile
- **AND** future Telegram deliveries for that account fail gracefully until a new profile is configured

### Requirement: Cloak vault configuration
The system SHALL provide a GoodIssues Cloak vault and encrypted binary Ecto type for sensitive integration fields. The vault SHALL use a 32-byte AES-GCM key decoded from `CLOAK_KEY`.

#### Scenario: Valid Cloak key starts vault
- **WHEN** `CLOAK_KEY` decodes to exactly 32 bytes
- **THEN** the system starts the GoodIssues vault successfully

#### Scenario: Invalid Cloak key fails fast
- **WHEN** `CLOAK_KEY` is missing or does not decode to exactly 32 bytes
- **THEN** the system fails startup with a clear configuration error
