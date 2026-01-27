## ADDED Requirements

### Requirement: Audit Trail Logging
The system SHALL record audit log entries for all account management operations.

#### Scenario: Log account creation
- **WHEN** an admin creates a new account
- **THEN** an audit log entry is created with action "account_created"
- **AND** the entry includes: account_id, actor_id, timestamp, metadata

#### Scenario: Log account update
- **WHEN** an admin updates an account
- **THEN** an audit log entry is created with action "account_updated"
- **AND** the entry includes the changed fields in metadata

#### Scenario: Log status change
- **WHEN** an admin activates or deactivates an account
- **THEN** an audit log entry is created with action "status_changed"
- **AND** the entry includes the old and new status in metadata

#### Scenario: Log role change
- **WHEN** an admin changes an account's role
- **THEN** an audit log entry is created with action "role_changed"
- **AND** the entry includes the old and new role in metadata

### Requirement: Audit Trail Display
The admin interface SHALL display account audit history on the account detail page.

#### Scenario: View account audit trail
- **WHEN** an admin views an account detail page
- **THEN** a list of audit log entries for that account is displayed
- **AND** entries show: timestamp, action type, actor name, and relevant details
- **AND** entries are sorted by timestamp (newest first)
- **AND** the list is paginated

#### Scenario: Filter audit trail by action
- **WHEN** an admin selects an action type filter
- **THEN** the audit trail is filtered to show only matching entries
- **AND** pagination updates to reflect filtered results
