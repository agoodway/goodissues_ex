## ADDED Requirements

### Requirement: Sentry Envelope Endpoint
The system SHALL accept Sentry SDK envelope payloads at `POST /api/:sentry_project_id/envelope/` and translate them into GoodIssues error reports.

#### Scenario: Successful exception ingestion
- **WHEN** a Sentry SDK sends a POST to `/api/:sentry_project_id/envelope/` with a valid `X-Sentry-Auth` header and an envelope containing an event with an `exception` array
- **THEN** the system SHALL create or update an Error (via fingerprint dedup) with an Occurrence and Stacktrace for each exception in the array
- **AND** return 200 with `{"id": "<event_id>"}` where event_id is from the envelope header

#### Scenario: Multi-exception event
- **WHEN** an envelope event contains multiple exceptions (chained errors)
- **THEN** the system SHALL compute an independent fingerprint for each exception
- **AND** create or update a separate Error record per exception
- **AND** attach shared event context (tags, user, environment, breadcrumbs) to every Occurrence created

#### Scenario: Duplicate exception (existing fingerprint)
- **WHEN** an envelope event contains an exception whose fingerprint matches an existing Error
- **THEN** the system SHALL add a new Occurrence to the existing Error
- **AND** update the Error's `last_occurrence_at` timestamp
- **AND** NOT create a new Issue

#### Scenario: New exception (no matching fingerprint)
- **WHEN** an envelope event contains an exception whose fingerprint does not match any existing Error
- **THEN** the system SHALL create a new Issue (type: bug) with title set to the exception type
- **AND** create a new Error linked 1:1 to the Issue
- **AND** create the first Occurrence with stacktrace lines

### Requirement: Sentry Envelope Parsing
The system SHALL parse the Sentry envelope binary format as defined by the Sentry SDK protocol.

#### Scenario: Valid envelope with event item
- **WHEN** the request body contains a valid envelope (line-delimited: envelope header JSON, item header JSON with `type` and `length`, item payload)
- **THEN** the system SHALL extract the event_id from the envelope header
- **AND** parse each item according to its `type` and `length` fields

#### Scenario: Envelope with multiple items
- **WHEN** an envelope contains multiple items (e.g., event + attachment)
- **THEN** the system SHALL process supported item types and silently ignore unsupported ones

#### Scenario: Malformed envelope
- **WHEN** the request body is not a valid envelope (truncated, invalid JSON, wrong length)
- **THEN** the system SHALL return 200 with `{"id": null}` to prevent SDK retry storms
- **AND** log the parse failure for debugging

### Requirement: Sentry Auth via X-Sentry-Auth Header
The system SHALL authenticate Sentry SDK requests using the `X-Sentry-Auth` header format.

#### Scenario: Valid authentication
- **WHEN** the request includes header `X-Sentry-Auth: Sentry sentry_version=5, sentry_key=<api_key_token>, ...`
- **THEN** the system SHALL extract the `sentry_key` value
- **AND** look up the corresponding API key by token
- **AND** resolve the account and user from the API key
- **AND** assign `:current_account`, `:current_user`, and `:current_api_key` to the connection

#### Scenario: Missing auth header
- **WHEN** the request does not include an `X-Sentry-Auth` header
- **THEN** the system SHALL return 401 Unauthorized

#### Scenario: Invalid API key in sentry_key
- **WHEN** the `sentry_key` value does not match any active API key
- **THEN** the system SHALL return 401 Unauthorized

#### Scenario: Revoked or expired API key
- **WHEN** the `sentry_key` matches an API key that is revoked or expired
- **THEN** the system SHALL return 401 Unauthorized

### Requirement: Sentry Event Type Routing
The system SHALL route different Sentry event types to appropriate handlers.

#### Scenario: Exception event
- **WHEN** an envelope item has type `event` and the payload contains an `exception` array
- **THEN** the system SHALL process each exception via `Tracking.report_error/5`

#### Scenario: Message-only event
- **WHEN** an envelope item has type `event` and the payload contains a `message` but no `exception`
- **THEN** the system SHALL create an error with kind "message" and fingerprint derived from the message template

#### Scenario: Transaction event
- **WHEN** an envelope item has type `transaction`
- **THEN** the system SHALL create telemetry span(s) from the transaction data

#### Scenario: Session event
- **WHEN** an envelope item has type `session`
- **THEN** the system SHALL return 200 and silently discard the data

#### Scenario: Attachment or client_report
- **WHEN** an envelope item has type `attachment` or `client_report`
- **THEN** the system SHALL silently ignore the item and continue processing remaining items

### Requirement: Sentry Field Mapping
The system SHALL translate Sentry event fields to GoodIssues data model fields.

#### Scenario: Exception fields to Error
- **WHEN** processing a Sentry exception
- **THEN** `exception.type` SHALL map to `Error.kind`
- **AND** `exception.value` SHALL map to `Error.reason` and `Occurrence.reason`
- **AND** the last stacktrace frame's `file:lineno` SHALL map to `Error.source_line`
- **AND** the last stacktrace frame's `module.function` SHALL map to `Error.source_function`

#### Scenario: Stacktrace frame mapping
- **WHEN** processing Sentry stacktrace frames
- **THEN** frames SHALL be reversed (Sentry sends oldest-first, GoodIssues stores crash-site as position 0)
- **AND** each frame's `module`, `function`, `filename`, `lineno` SHALL map to StacktraceLine fields
- **AND** `in_app` SHALL be used to derive the `application` field

#### Scenario: Context and breadcrumbs mapping
- **WHEN** a Sentry event contains `tags`, `contexts`, `extra`, and/or `user` fields
- **THEN** they SHALL be merged into `Occurrence.context` as a single map
- **AND** `breadcrumbs[].message` values SHALL map to `Occurrence.breadcrumbs` string array

#### Scenario: Level to priority mapping
- **WHEN** a Sentry event has a `level` field
- **THEN** it SHALL map to Issue priority: `fatal` → critical, `error` → high, `warning` → medium, `info` or `debug` → low

### Requirement: Fingerprint Computation
The system SHALL compute fingerprints for deduplication using exception type and stacktrace.

#### Scenario: Exception fingerprint
- **WHEN** computing a fingerprint for a Sentry exception
- **THEN** the fingerprint SHALL be `SHA256(exception.type + "|" + normalized_frames)`
- **AND** normalized frames SHALL use `module.function/arity:line` format joined by `|`
- **AND** file paths SHALL be excluded from the fingerprint (they change across deploys)

#### Scenario: Message fingerprint
- **WHEN** computing a fingerprint for a message-only event
- **THEN** the fingerprint SHALL be `SHA256("message|" + message_template)`
- **AND** the template (not the formatted message) SHALL be used to ensure consistent grouping

### Requirement: Rate Limiting
The Sentry ingest endpoint SHALL be rate limited.

#### Scenario: Rate limit enforcement
- **WHEN** requests to the envelope endpoint exceed the rate limit
- **THEN** the system SHALL return 429 Too Many Requests
- **AND** include a `Retry-After` header with seconds until the limit resets

#### Scenario: SDK rate limit compliance
- **WHEN** a 429 response is returned
- **THEN** the response format SHALL be compatible with Sentry SDK retry logic
