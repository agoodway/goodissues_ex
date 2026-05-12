## ADDED Requirements

### Requirement: OTel trace correlation on errors
The system SHALL support correlating error issues with OTel traces via `trace_id`. When an error issue has a `trace_id` and matching OTel spans exist, the system SHALL allow querying the related trace.

#### Scenario: Error with matching OTel trace
- **WHEN** an error issue has a `trace_id` field and `otel_spans` contain spans with that `trace_id` in the same project
- **THEN** the related OTel spans can be queried alongside the error details

#### Scenario: Error without trace_id
- **WHEN** an error issue does not have a `trace_id`
- **THEN** no OTel trace correlation is available and the error displays without trace data

#### Scenario: Error with trace_id but no matching spans
- **WHEN** an error issue has a `trace_id` but no `otel_spans` exist with that `trace_id`
- **THEN** the system indicates no trace data is available for this error
