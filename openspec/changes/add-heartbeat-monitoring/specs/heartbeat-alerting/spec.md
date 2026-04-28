## ADDED Requirements

### Requirement: Alert rules configuration
The system SHALL allow users to configure alert_rules as a JSON array on heartbeats. Each rule MUST specify a field (string), op (one of: eq, neq, gt, gte, lt, lte), and value (number or string). Rules are evaluated against the JSON payload of incoming success pings.

#### Scenario: Create heartbeat with alert rules
- **WHEN** a user creates a heartbeat with alert_rules [{"field": "rows_processed", "op": "lt", "value": 100}]
- **THEN** the system stores the rules and validates their structure

#### Scenario: Invalid rule structure rejected
- **WHEN** a user creates a heartbeat with alert_rules [{"field": "x"}] (missing op and value)
- **THEN** the system returns a 422 validation error

#### Scenario: Invalid operator rejected
- **WHEN** a user creates a heartbeat with alert_rules [{"field": "x", "op": "contains", "value": "y"}]
- **THEN** the system returns a 422 validation error because "contains" is not a supported operator

#### Scenario: Update alert rules
- **WHEN** a user updates a heartbeat's alert_rules to a new set of rules
- **THEN** the system replaces the existing rules entirely (not merged)

### Requirement: Alert rule evaluation on ping
The system SHALL evaluate all alert_rules against the JSON payload of every success ping (/ping endpoint). If ANY rule matches (the condition is true), the system MUST treat the ping as a logical failure — incrementing consecutive_failures and evaluating the incident threshold — even though the ping was received.

#### Scenario: Rule triggers on payload field
- **WHEN** a ping arrives with payload {"rows_processed": 0} and the heartbeat has rule {"field": "rows_processed", "op": "lt", "value": 100}
- **THEN** the system treats this as a failure, increments consecutive_failures, and evaluates incident threshold

#### Scenario: All rules pass
- **WHEN** a ping arrives with payload {"rows_processed": 500} and the heartbeat has rule {"field": "rows_processed", "op": "lt", "value": 100}
- **THEN** the system treats this as a success, resets consecutive_failures, and sets status to :up

#### Scenario: Multiple rules with one failing
- **WHEN** a ping arrives with payload {"rows": 500, "errors": 3} and rules [{"field": "rows", "op": "lt", "value": 100}, {"field": "errors", "op": "gt", "value": 0}]
- **THEN** the system treats this as a failure because the errors rule matched (ANY rule match = failure)

#### Scenario: Missing field in payload
- **WHEN** a ping arrives with payload {"duration_ms": 100} but a rule targets field "rows_processed"
- **THEN** the system skips that rule (missing field does not trigger the rule)

#### Scenario: Ping with no payload and rules configured
- **WHEN** a ping arrives with no JSON body and the heartbeat has alert_rules configured
- **THEN** the system skips all rule evaluation (no payload = no fields to match) and treats as success

### Requirement: Duration-based alerting via rules
The system SHALL make the computed duration_ms field available for alert rule evaluation. When a /start preceded the /ping, the computed duration_ms is included as a virtual field in rule evaluation alongside any payload fields.

#### Scenario: Duration exceeds threshold
- **WHEN** a /start is sent, then /ping arrives 10 minutes later, and the heartbeat has rule {"field": "duration_ms", "op": "gt", "value": 300000}
- **THEN** the system evaluates duration_ms = ~600000, rule matches, treats as failure

#### Scenario: Duration within threshold
- **WHEN** a /start is sent, then /ping arrives 2 minutes later, and the heartbeat has rule {"field": "duration_ms", "op": "gt", "value": 300000}
- **THEN** the system evaluates duration_ms = ~120000, rule does not match, treats as success

#### Scenario: No start ping means no duration_ms
- **WHEN** a /ping arrives without a preceding /start and a rule targets duration_ms
- **THEN** the system skips the duration_ms rule (field not available)

### Requirement: Alert rule evaluation does not block ping recording
The system SHALL always record the HeartbeatPing regardless of alert rule evaluation outcome. Rule evaluation determines whether the ping counts as a logical success or failure, but the ping record MUST be persisted in all cases.

#### Scenario: Failed rule still records ping
- **WHEN** a ping arrives and an alert rule fires
- **THEN** the ping is recorded in heartbeat_pings with kind :ping, AND the heartbeat's consecutive_failures is incremented

#### Scenario: Ping recorded even on evaluation error
- **WHEN** a ping arrives with payload {"count": "not_a_number"} and a rule uses op "gt" with value 100
- **THEN** the ping is still recorded, and the rule evaluation skips that rule (type mismatch = skip)
