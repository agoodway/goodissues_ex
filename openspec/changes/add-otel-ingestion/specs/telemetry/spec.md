## REMOVED Requirements

### Requirement: Telemetry Span Storage
**Reason**: Replaced by OTel-native span storage in `otel-storage`. The custom `telemetry_spans` table and `GI.Telemetry` context are superseded by `otel_spans` and `GI.Otel`.
**Migration**: Configure projects with `otel_service_name` and point OTel SDK exporters at `POST /api/v1/otlp/traces`. Legacy telemetry data is ephemeral and not migrated.

### Requirement: Batch Span Creation
**Reason**: Replaced by OTLP bulk span insertion via `GI.Otel.Storage.insert_spans/2`.
**Migration**: Use OTLP HTTP/protobuf endpoint instead of custom batch API.

### Requirement: Project Ownership Validation
**Reason**: Project resolution now uses `otel_service_name` from OTLP resource attributes instead of explicit `project_id` in request params. Account scoping is enforced via Bearer token auth.
**Migration**: Set `otel_service_name` on projects to match the `service.name` OTel resource attribute.

### Requirement: Request ID Correlation
**Reason**: Replaced by OTel trace_id correlation. OTel traces provide richer correlation than request_id-based span grouping.
**Migration**: Use `trace_id` based queries via `GI.Otel.Storage.query_spans_by_trace_id/2`.

### Requirement: Span Listing with Filters
**Reason**: Replaced by `GI.Otel.Storage.query_spans/2` with time-range and attribute filters on the OTel span model.
**Migration**: Use new OTel query interfaces.

### Requirement: Events Batch API Endpoint
**Reason**: The `POST /api/v1/events/batch` endpoint is replaced by standard OTLP endpoints at `POST /api/v1/otlp/traces` and `POST /api/v1/otlp/metrics`.
**Migration**: Configure OTel SDK with OTLP HTTP exporter pointing at the new endpoints.

### Requirement: Events API Authentication
**Reason**: The `events:write` scope is replaced by `otel:write` scope. Authentication continues to use Bearer token auth.
**Migration**: Generate new API keys with `otel:write` scope. Remove `events:write` and `events:read` scopes.
