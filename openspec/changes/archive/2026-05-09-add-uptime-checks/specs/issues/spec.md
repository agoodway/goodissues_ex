## MODIFIED Requirements

### Requirement: Issue Type Enum

The issue type enum SHALL include :incident alongside :bug and :feature_request.

#### Scenario: Create issue with type incident
- **WHEN** an issue is created with type :incident
- **THEN** the issue is persisted with type :incident

#### Scenario: Filter issues by type incident
- **WHEN** listing issues with type filter set to "incident"
- **THEN** only issues with type :incident are returned

#### Scenario: Existing types unchanged
- **WHEN** an issue is created with type :bug or :feature_request
- **THEN** behavior is unchanged from current implementation
