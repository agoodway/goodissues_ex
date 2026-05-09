## ADDED Requirements

### Requirement: Telemetry Span Storage

The system SHALL store telemetry spans with the following attributes:
- `id` - Unique identifier (UUID)
- `project_id` - Reference to the project (required)
- `request_id` - Correlation ID for grouping spans within a request
- `trace_id` - Distributed tracing identifier
- `event_type` - Type of event (phoenix_request, phoenix_router, phoenix_error, liveview_mount, liveview_event, ecto_query)
- `event_name` - Descriptive name of the event (required)
- `timestamp` - When the event occurred (required, microsecond precision)
- `duration_ms` - Event duration in milliseconds
- `context` - Arbitrary context data (map)
- `measurements` - Numeric measurements (map)

#### Scenario: Store span with all fields

- **WHEN** a span is created with all attributes populated
- **THEN** all attributes are persisted correctly
- **AND** the span is associated with the correct project

#### Scenario: Store span with minimal fields

- **WHEN** a span is created with only required fields (project_id, event_type, event_name, timestamp)
- **THEN** the span is persisted with defaults for optional fields

### Requirement: Batch Span Creation

The system SHALL support creating multiple spans in a single operation for efficient bulk ingestion.

#### Scenario: Create multiple spans in batch

- **WHEN** a batch of span parameters is submitted
- **THEN** all valid spans are inserted in a single database operation
- **AND** the count of inserted spans is returned

#### Scenario: Batch with empty list

- **WHEN** an empty list of spans is submitted
- **THEN** zero spans are inserted
- **AND** the operation succeeds with count 0

### Requirement: Project Ownership Validation

The system SHALL validate that spans belong to projects owned by the authenticated account.

#### Scenario: Valid project ownership

- **WHEN** spans are submitted for a project owned by the account
- **THEN** the spans are created successfully

#### Scenario: Invalid project ownership

- **WHEN** spans are submitted for a project not owned by the account
- **THEN** the operation fails with project_not_found error
- **AND** no spans are created

#### Scenario: Non-existent project

- **WHEN** spans are submitted for a non-existent project ID
- **THEN** the operation fails with project_not_found error

### Requirement: Request ID Correlation

The system SHALL support querying spans by request_id to correlate all events within a single request.

#### Scenario: Query spans by request_id

- **WHEN** spans are queried by request_id
- **THEN** all spans with matching request_id are returned
- **AND** spans are ordered by timestamp ascending

#### Scenario: Request ID isolation between accounts

- **WHEN** spans are queried by request_id
- **THEN** only spans from projects owned by the account are returned

### Requirement: Span Listing with Filters

The system SHALL support listing spans for a project with optional filters.

#### Scenario: List spans with limit

- **WHEN** spans are listed with a limit option
- **THEN** at most the specified number of spans are returned
- **AND** spans are ordered by timestamp descending (most recent first)

#### Scenario: Filter spans by event_type

- **WHEN** spans are listed with an event_type filter
- **THEN** only spans matching the event type are returned

### Requirement: Events Batch API Endpoint

The system SHALL provide a REST API endpoint for batch event ingestion at `POST /api/v1/events/batch`.

#### Scenario: Successful batch creation

- **WHEN** a valid batch of events is submitted via API
- **THEN** HTTP 201 is returned with inserted count
- **AND** all valid events are persisted

#### Scenario: Mixed valid and invalid projects

- **WHEN** a batch contains events for both valid and invalid projects
- **THEN** HTTP 201 is returned
- **AND** valid events are inserted
- **AND** errors are returned for invalid projects

#### Scenario: Missing events array

- **WHEN** a request is submitted without an events array
- **THEN** HTTP 400 is returned with error message

### Requirement: Events API Authentication

The system SHALL require authentication with `events:write` scope for the batch endpoint.

#### Scenario: No authentication

- **WHEN** a request is submitted without authentication
- **THEN** HTTP 401 is returned

#### Scenario: Read-only API key

- **WHEN** a request is submitted with a read-only (public) API key
- **THEN** HTTP 403 is returned

#### Scenario: Write API key

- **WHEN** a request is submitted with a private (write) API key
- **THEN** the request is processed normally
