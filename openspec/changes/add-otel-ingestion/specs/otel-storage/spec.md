## ADDED Requirements

### Requirement: OTel span storage
The system SHALL store OpenTelemetry spans with the full OTel data model: trace_id (32 hex chars), span_id (16 hex chars), parent_span_id, name, kind, status, status_message, start_time, end_time, attributes, resource, events, links, and instrumentation_scope.

#### Scenario: Store span with all fields
- **WHEN** a span is inserted with all OTel fields populated
- **THEN** all fields are persisted correctly
- **AND** the span is associated with the correct project

#### Scenario: Store span with minimal fields
- **WHEN** a span is inserted with only required fields (project_id, trace_id, span_id, name, kind, status, start_time, end_time)
- **THEN** the span is persisted with default empty values for attributes, resource, events, links, and instrumentation_scope

### Requirement: OTel metric storage
The system SHALL store OpenTelemetry metrics with name, description, unit, type (gauge/sum/histogram/exponential_histogram/summary), monotonicity, aggregation temporality, resource, instrumentation_scope, data_points (JSONB), and timestamp.

#### Scenario: Store gauge metric
- **WHEN** a gauge metric with data points is inserted
- **THEN** the metric is stored with type `gauge` and the data_points JSONB contains the gauge values

#### Scenario: Store histogram metric
- **WHEN** a histogram metric with bucket counts, explicit bounds, sum, and count is inserted
- **THEN** the metric is stored with type `histogram` and the data_points JSONB preserves the full histogram structure

### Requirement: Bulk span insertion
The system SHALL support inserting multiple spans in a single operation for efficient batch ingestion.

#### Scenario: Bulk insert spans
- **WHEN** a list of span parameter maps is submitted to the storage backend
- **THEN** all spans are inserted in a single database operation
- **AND** the count of inserted spans is returned

#### Scenario: Bulk insert with empty list
- **WHEN** an empty list of spans is submitted
- **THEN** zero spans are inserted and the operation succeeds with count 0

### Requirement: Bulk metric insertion
The system SHALL support inserting multiple metrics in a single operation.

#### Scenario: Bulk insert metrics
- **WHEN** a list of metric parameter maps is submitted to the storage backend
- **THEN** all metrics are inserted in a single database operation
- **AND** the count of inserted metrics is returned

### Requirement: Span query by trace ID
The system SHALL support querying all spans within a trace by trace_id, scoped to a project.

#### Scenario: Query spans by trace_id
- **WHEN** spans are queried by trace_id for a project
- **THEN** all spans with matching trace_id are returned
- **AND** spans are ordered by start_time ascending

#### Scenario: Trace ID isolation between projects
- **WHEN** two projects have spans with the same trace_id
- **THEN** querying by trace_id for one project returns only that project's spans

### Requirement: Span query with filters
The system SHALL support listing spans for a project with time range, limit, and attribute filters.

#### Scenario: List spans with time range
- **WHEN** spans are queried with a start_time and end_time range
- **THEN** only spans within that time range are returned

#### Scenario: List spans with limit
- **WHEN** spans are listed with a limit option
- **THEN** at most the specified number of spans are returned ordered by start_time descending

### Requirement: Storage behaviour abstraction
The system SHALL define a `GI.Otel.Storage` behaviour with callbacks for insert_spans, insert_metrics, query_spans, query_metrics, query_spans_by_trace_id, and prune. The Postgres implementation SHALL be the default backend.

#### Scenario: Storage backend is configurable
- **WHEN** the application config sets `config :good_issues, GI.Otel, storage: GI.Otel.Storage.Postgres`
- **THEN** the OTel context uses the Postgres storage backend for all operations

### Requirement: OTel service name on projects
The system SHALL support an optional `otel_service_name` field on projects for OTLP-to-project mapping, unique per account.

#### Scenario: Set otel_service_name on project
- **WHEN** a project is created or updated with an `otel_service_name`
- **THEN** the service name is stored and available for OTLP project resolution

#### Scenario: Unique otel_service_name per account
- **WHEN** two projects in the same account attempt to use the same `otel_service_name`
- **THEN** the second operation fails with a uniqueness error

#### Scenario: Same service name across different accounts
- **WHEN** two projects in different accounts use the same `otel_service_name`
- **THEN** both are accepted since uniqueness is scoped per account
