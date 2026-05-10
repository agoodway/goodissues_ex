## ADDED Requirements

### Requirement: Manager-only heartbeat ping URL reveal
The system SHALL provide an explicit manager-only dashboard capability for revealing a heartbeat's full ping URL. Normal heartbeat management read responses SHALL continue to redact token-bearing fields after creation.

#### Scenario: Manager reveals heartbeat ping URL
- **WHEN** a user with manage permission requests to reveal a heartbeat ping URL from the dashboard
- **THEN** the system returns the full `/api/v1/projects/:project_id/heartbeats/:heartbeat_token/ping` URL for that heartbeat

#### Scenario: Non-manager cannot reveal heartbeat ping URL
- **WHEN** a user without manage permission requests to reveal a heartbeat ping URL
- **THEN** the system denies the request
- **AND** the response does not include the ping token or full ping URL

#### Scenario: Normal management reads remain redacted
- **WHEN** a caller fetches heartbeat management data after creation through the existing list, show, or update reads
- **THEN** the response omits or masks `ping_token` and full ping URLs
