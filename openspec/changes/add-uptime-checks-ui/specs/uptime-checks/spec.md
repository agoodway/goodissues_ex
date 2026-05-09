## MODIFIED Requirements

### Requirement: Check Execution
The system SHALL execute HTTP checks using Req and record the result.

#### Scenario: Failed check persists down status for dashboard consumers
- **WHEN** a check execution fails for any reason
- **THEN** the check's status is set to `:down`
- **AND** the check's last_checked_at is updated
- **AND** the check's consecutive_failures is incremented by 1

## ADDED Requirements

### Requirement: Check lifecycle broadcasts
The system SHALL broadcast uptime check lifecycle events via PubSub on the topic `"checks:project:<project_id>"` so project-scoped dashboard consumers can update in realtime.

#### Scenario: Check CRUD broadcasts
- **WHEN** a check is created, updated, or deleted via the Monitoring context
- **THEN** a PubSub message is broadcast on the check's project topic with the event type and a payload sufficient to update or remove the affected row without re-querying

#### Scenario: Check run completion broadcasts
- **WHEN** the CheckRunner worker completes a check execution
- **THEN** a PubSub message is broadcast on the check's project topic with the updated check status, last_checked_at, and consecutive_failures
