## ADDED Requirements
### Requirement: Default Account Creation
When a user registers, the system SHALL automatically create a default personal account for them.

#### Scenario: Successful registration creates default account
- **WHEN** a user successfully registers with valid credentials
- **THEN** a new account named "Personal" is created
- **AND** the user is added as the owner of that account
- **AND** the account has status "active"

#### Scenario: Registration transaction atomicity
- **WHEN** a user registration is attempted
- **AND** the user record is created successfully
- **AND** the default account creation fails
- **THEN** both the user and account creation are rolled back
- **AND** an error is returned

#### Scenario: Default account properties
- **WHEN** a default account is created during registration
- **THEN** the account name is "Personal"
- **AND** the account slug is generated from the name
- **AND** the account status is "active"
