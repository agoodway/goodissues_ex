## ADDED Requirements

### Requirement: Shared error dedup mechanics

#### Scenario: Report error dedup uses shared pattern
- **WHEN** `report_error/5` is called
- **THEN** the advisory-lock and find-or-create logic SHALL use the same shared private helper functions as `report_incident/5`
- **AND** the external behavior of `report_error/5` SHALL remain unchanged
- **AND** the fingerprint validation (exactly 64 characters) SHALL remain unchanged for errors
