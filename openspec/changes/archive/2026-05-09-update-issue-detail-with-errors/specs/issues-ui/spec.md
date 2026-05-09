## MODIFIED Requirements

### Requirement: Issue Detail View
The dashboard SHALL provide a detail view showing all issue information including linked error data when present.

#### Scenario: Display issue without error data
- **WHEN** viewing an issue that has no linked error
- **THEN** the issue detail page displays: title, description, type, status, priority, project, submitter, timestamps
- **AND** no error section is shown

#### Scenario: Display issue with error data
- **WHEN** viewing an issue that has a linked error
- **THEN** the issue detail page displays an ERROR DATA section
- **AND** the section shows: error kind, error reason, error status (resolved/unresolved), muted flag, occurrence count, last occurrence timestamp
- **AND** the section shows a collapsible stacktrace from the latest occurrence (collapsed by default)

#### Scenario: Expand stacktrace
- **GIVEN** viewing an issue with linked error data
- **WHEN** the user clicks the stacktrace expand toggle
- **THEN** the full stacktrace is displayed showing: module, function/arity, file, line for each frame
- **AND** clicking again collapses the stacktrace

#### Scenario: Toggle error muted status
- **GIVEN** a user with manage permissions viewing an issue with linked error
- **WHEN** the user clicks the mute toggle
- **THEN** the error's muted flag is toggled
- **AND** the UI updates to reflect the new muted state

#### Scenario: Toggle error resolved status
- **GIVEN** a user with manage permissions viewing an issue with linked error
- **WHEN** the user clicks the status toggle
- **THEN** the error's status toggles between resolved and unresolved
- **AND** the UI updates to reflect the new status

#### Scenario: Read-only error display
- **GIVEN** a user without manage permissions viewing an issue with linked error
- **THEN** the error data is displayed
- **AND** the mute and status toggles are not shown
