## ADDED Requirements

### Requirement: Incident handling for heartbeat failures
The system SHALL extend the existing monitoring incident lifecycle semantics to heartbeat-driven failures and recoveries through the heartbeat-specific lifecycle wrapper or an equivalent generalized path.

#### Scenario: Heartbeat threshold reached from deadline or fail ping
- **WHEN** a heartbeat's `consecutive_failures` reaches `failure_threshold` because of a missed deadline or `/ping/fail`
- **THEN** the system creates or reopens an incident issue for that heartbeat using the bot user as submitter
- **AND** the heartbeat's `current_issue_id` is set to that issue
- **AND** if the threshold-crossing signal came from `/ping/fail`, the triggering `HeartbeatPing` stores that issue's id

#### Scenario: Heartbeat threshold reached from alert-rule failure
- **WHEN** a heartbeat receives a `/ping` but alert rule evaluation treats the ping as a logical failure and `consecutive_failures` reaches `failure_threshold`
- **THEN** the system creates or reopens an incident issue for that heartbeat using the same incident lifecycle as other monitoring failures
- **AND** the triggering `HeartbeatPing` stores that issue's id

#### Scenario: Heartbeat reopens a recent incident within window
- **WHEN** a heartbeat failure crosses `failure_threshold`
- **AND** no open incident issue exists
- **AND** the most recent archived incident for that heartbeat was archived within `reopen_window_hours`
- **THEN** the system reopens that existing incident instead of creating a new one

#### Scenario: Heartbeat threshold reached with an open incident already present
- **WHEN** a heartbeat failure crosses `failure_threshold`
- **AND** an open incident issue already exists for that heartbeat
- **THEN** the system does not create or reopen another incident
- **AND** the heartbeat keeps pointing at the existing `current_issue_id`
- **AND** if the threshold-crossing signal came from a recorded ping, that `HeartbeatPing` stores the existing `current_issue_id`

#### Scenario: Heartbeat recovery archives the current incident
- **WHEN** a heartbeat currently in `:down` state later receives a logical success ping
- **THEN** the system archives any open incident issue for that heartbeat
- **AND** clears `current_issue_id`
