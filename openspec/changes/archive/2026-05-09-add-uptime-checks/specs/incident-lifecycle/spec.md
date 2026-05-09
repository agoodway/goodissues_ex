## ADDED Requirements

### Requirement: Incident Creation on Failure

The system SHALL automatically create an incident issue when a check's consecutive failures reach or exceed the configured failure_threshold.

#### Scenario: Threshold reached — no prior incident
- **WHEN** a check's consecutive_failures reaches failure_threshold
- **AND** no open incident issue exists for the check
- **AND** no archived incident issue exists within reopen_window_hours
- **THEN** a new issue is created with type :incident, priority :critical, status :new
- **AND** the issue title is "DOWN: {check.name}"
- **AND** the issue description includes the check URL, the error from the latest check_result, and the failure count
- **AND** the issue is created under the check's project with the bot user as submitter
- **AND** the check's status is set to :down
- **AND** the check_result that triggered the incident stores the issue_id

#### Scenario: Threshold reached — open incident exists
- **WHEN** a check's consecutive_failures reaches failure_threshold
- **AND** an open incident issue (status :new or :in_progress) already exists for the check
- **THEN** no new issue is created

#### Scenario: Threshold reached — recent closed incident exists
- **WHEN** a check's consecutive_failures reaches failure_threshold
- **AND** no open incident issue exists
- **AND** an incident issue was archived within the last reopen_window_hours
- **THEN** the existing issue is reopened by setting status to :in_progress
- **AND** the check_result stores the reopened issue_id

#### Scenario: Threshold reached — old closed incident exists
- **WHEN** a check's consecutive_failures reaches failure_threshold
- **AND** the most recent archived incident was archived more than reopen_window_hours ago
- **THEN** a new incident issue is created

### Requirement: Incident Auto-Recovery

The system SHALL automatically archive incident issues when a check recovers.

#### Scenario: Check recovers after being down
- **WHEN** a check with status :down executes successfully (status :up)
- **THEN** the check's status is set to :up
- **AND** consecutive_failures is reset to 0
- **AND** any open incident issue (status :new or :in_progress) for the check is archived

#### Scenario: Archived issue gets status and timestamp
- **WHEN** an open incident issue is archived due to recovery
- **THEN** its status is set to :archived
- **AND** its archived_at is set to the current time

#### Scenario: Check recovers with no open incident
- **WHEN** a check with status :down executes successfully
- **AND** no open incident issue exists (e.g., manually archived)
- **THEN** the check's status is set to :up
- **AND** no issue changes are made

### Requirement: Incident Issue Linking

The system SHALL maintain a link between checks and their current incident issue for efficient lookup.

#### Scenario: Current issue tracking on check
- **WHEN** an incident issue is created or reopened for a check
- **THEN** the check's current_issue_id is set to that issue's ID

#### Scenario: Current issue cleared on recovery
- **WHEN** an incident issue is archived due to recovery
- **THEN** the check's current_issue_id is set to nil
