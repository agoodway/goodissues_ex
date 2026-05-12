## MODIFIED Requirements

### Requirement: Incident handling for heartbeat failures
The system SHALL route all heartbeat incident lifecycle operations through `Tracking.report_incident/5` and `Tracking.resolve_incident/2` instead of directly creating or updating issues. The heartbeat's identity SHALL be used to derive a stable fingerprint (e.g., `"heartbeat_<id>"`).

#### Scenario: Heartbeat threshold reached from deadline or fail ping
- **WHEN** a heartbeat's `consecutive_failures` reaches `failure_threshold` because of a missed deadline or `/ping/fail`
- **THEN** the system calls `Tracking.report_incident/5` with fingerprint `"heartbeat_<heartbeat_id>"`, the heartbeat's `reopen_window_hours` in `incident_attrs`, and relevant metadata
- **AND** the heartbeat's `current_issue_id` is set to the incident's linked issue
- **AND** if the threshold-crossing signal came from `/ping/fail`, the triggering `HeartbeatPing` stores that issue's id

#### Scenario: Heartbeat threshold reached from alert-rule failure
- **WHEN** a heartbeat receives a `/ping` but alert rule evaluation treats the ping as a logical failure and `consecutive_failures` reaches `failure_threshold`
- **THEN** the system calls `Tracking.report_incident/5` with the same fingerprint and lifecycle semantics as other monitoring failures
- **AND** the triggering `HeartbeatPing` stores the incident's linked issue id

#### Scenario: Heartbeat reopens a recent incident within window
- **WHEN** a heartbeat failure crosses `failure_threshold`
- **AND** no open incident issue exists
- **AND** the most recent archived incident for that heartbeat was archived within `reopen_window_hours`
- **THEN** `report_incident/5` reopens that existing incident instead of creating a new one

#### Scenario: Heartbeat threshold reached with an open incident already present
- **WHEN** a heartbeat failure crosses `failure_threshold`
- **AND** an open incident issue already exists for that heartbeat
- **THEN** `report_incident/5` adds an occurrence without creating or reopening
- **AND** the heartbeat keeps pointing at the existing `current_issue_id`
- **AND** if the threshold-crossing signal came from a recorded ping, that `HeartbeatPing` stores the existing `current_issue_id`

#### Scenario: Heartbeat recovery archives the current incident
- **WHEN** a heartbeat currently in `:down` state later receives a logical success ping
- **THEN** the system calls `Tracking.resolve_incident/2` to resolve the incident and archive the linked issue
- **AND** clears `current_issue_id`

## ADDED Requirements

### Requirement: Check incident lifecycle uses report_incident
The system SHALL route all check-based incident lifecycle operations through `Tracking.report_incident/5` and `Tracking.resolve_incident/2`. The check's identity SHALL be used to derive a stable fingerprint (e.g., `"check_<id>"`).

#### Scenario: Check crosses failure threshold
- **WHEN** a check's `consecutive_failures` reaches `failure_threshold`
- **THEN** the system calls `Tracking.report_incident/5` with fingerprint `"check_<check_id>"`, the check's `reopen_window_hours` in `incident_attrs`, severity `:critical`, and check result metadata
- **AND** the check's `current_issue_id` is set to the incident's linked issue
- **AND** the check_result's `issue_id` is set to the incident's linked issue

#### Scenario: Check recovery
- **WHEN** a check transitions from down to up
- **THEN** the system calls `Tracking.resolve_incident/2`
- **AND** the check's `current_issue_id` is cleared and status set to `:up`
