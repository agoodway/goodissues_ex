## ADDED Requirements

### Requirement: OTLP trace receiver endpoint
The system SHALL provide an HTTP endpoint at `POST /api/v1/otlp/traces` that accepts OTLP trace data encoded as protobuf.

#### Scenario: Successful trace ingestion
- **WHEN** a client sends an `ExportTraceServiceRequest` protobuf body with `Content-Type: application/x-protobuf` and valid Bearer token auth
- **THEN** the system decodes the protobuf, extracts `resource_spans`, resolves each to a project via `service.name` resource attribute, and stores the spans
- **AND** returns an `ExportTraceServiceResponse` with HTTP 200

#### Scenario: Partial success with unknown service name
- **WHEN** an OTLP request contains multiple `ResourceSpans` entries and one has a `service.name` that does not match any project's `otel_service_name` within the account
- **THEN** the system inserts spans for matched projects and rejects unmatched batches
- **AND** returns HTTP 200 with `rejected_spans` count in the response

#### Scenario: All service names unresolvable
- **WHEN** no `ResourceSpans` entries match any project's `otel_service_name` within the account
- **THEN** the system returns HTTP 200 with all spans rejected
- **AND** no spans are stored

#### Scenario: Invalid protobuf body
- **WHEN** the request body cannot be decoded as an `ExportTraceServiceRequest`
- **THEN** the system returns HTTP 400 with an error message

#### Scenario: Unsupported content type
- **WHEN** the request uses a content type other than `application/x-protobuf`
- **THEN** the system returns HTTP 415 Unsupported Media Type

### Requirement: OTLP metrics receiver endpoint
The system SHALL provide an HTTP endpoint at `POST /api/v1/otlp/metrics` that accepts OTLP metric data encoded as protobuf.

#### Scenario: Successful metric ingestion
- **WHEN** a client sends an `ExportMetricsServiceRequest` protobuf body with `Content-Type: application/x-protobuf` and valid Bearer token auth
- **THEN** the system decodes the protobuf, extracts `resource_metrics`, resolves each to a project via `service.name`, and stores the metrics
- **AND** returns an `ExportMetricsServiceResponse` with HTTP 200

#### Scenario: Partial success with unknown service name
- **WHEN** an OTLP metrics request contains entries with unresolvable `service.name` values
- **THEN** the system stores metrics for matched projects and rejects unmatched batches

### Requirement: OTLP gzip decompression
The system SHALL support gzip-compressed request bodies for OTLP endpoints.

#### Scenario: Gzip-compressed trace request
- **WHEN** a trace request includes `Content-Encoding: gzip` and a gzip-compressed protobuf body
- **THEN** the system decompresses the body before decoding the protobuf
- **AND** processes the request normally

#### Scenario: Gzip-compressed metrics request
- **WHEN** a metrics request includes `Content-Encoding: gzip` and a gzip-compressed protobuf body
- **THEN** the system decompresses the body before decoding the protobuf
- **AND** processes the request normally

### Requirement: OTLP authentication and authorization
The system SHALL require Bearer token auth with `otel:write` scope for OTLP ingestion endpoints.

#### Scenario: Valid write key with otel:write scope
- **WHEN** a request includes a Bearer token with `otel:write` scope
- **THEN** the system processes the request and resolves projects within the token's account

#### Scenario: No authentication
- **WHEN** a request is submitted without a Bearer token
- **THEN** the system returns HTTP 401

#### Scenario: Read-only API key
- **WHEN** a request is submitted with a read-only (`pk_*`) API key
- **THEN** the system returns HTTP 403

#### Scenario: Write key without otel:write scope
- **WHEN** a request is submitted with an `sk_*` key that does not have `otel:write` scope
- **THEN** the system returns HTTP 403

### Requirement: Project resolution via otel_service_name
The system SHALL resolve OTLP resource `service.name` attributes to projects using the `otel_service_name` column, scoped to the authenticated account.

#### Scenario: Service name matches project
- **WHEN** a ResourceSpans entry has `resource.attributes` containing `service.name` = "my-app" and the account has a project with `otel_service_name` = "my-app"
- **THEN** the spans are stored under that project

#### Scenario: Service name not configured on any project
- **WHEN** a ResourceSpans entry has a `service.name` that does not match any project's `otel_service_name` within the account
- **THEN** those spans are rejected
- **AND** the rejection is counted in the response

#### Scenario: Missing service.name attribute
- **WHEN** a ResourceSpans entry has no `service.name` in its resource attributes
- **THEN** those spans are rejected
