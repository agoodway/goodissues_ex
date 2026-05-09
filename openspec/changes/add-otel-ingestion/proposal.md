## Supersedes

- `add-telemetry-events-api` — this change replaces the custom telemetry events API with OTLP-native ingestion
- `add-telemetry-ui-to-issue-detail` — the telemetry UI will be updated to use OTel spans instead of legacy telemetry spans

## Why

GoodIssues's telemetry system currently uses a custom reporter format with a Phoenix-specific data model. This limits it to Elixir/Phoenix apps and couples clients to a proprietary protocol. By adopting OpenTelemetry Protocol (OTLP) as the ingestion format, GoodIssues can collect traces and metrics from any language or framework that has an OTel SDK — which is effectively all of them. Users point their standard OTLP exporter at GoodIssues and get full observability correlated with their error tracking.

The existing `telemetry_spans` table and `/api/v1/events` endpoint will be replaced entirely with an OTel-native data model and OTLP HTTP/protobuf receiver.

## What Changes

- New OTLP HTTP/protobuf receiver endpoints for traces and metrics
- New `otel_spans` table with full OTel span model (trace_id, span_id, parent_span_id, kind, status, attributes, events, links, resource, instrumentation_scope)
- New `otel_metrics` table for raw metric data points (gauges, sums, histograms) stored as JSONB
- New `otel_service_name` field on projects for stable OTLP-to-project mapping
- Storage behaviour (`GI.Otel.Storage`) with Postgres v1 implementation, designed for swappable backends (ClickHouse, BigQuery)
- Per-project TTL-based data pruning via Oban cron job
- Drop existing `telemetry_spans` table and `/api/v1/events` endpoint
- GoodIssuesReporter exception data correlates with OTel traces via `trace_id`

## Capabilities

### New Capabilities

- `otel-ingestion`: OTLP HTTP/protobuf receiver for traces and metrics with protobuf decoding, project resolution via `otel_service_name`, and account-scoped auth
- `otel-storage`: Storage behaviour with Postgres implementation for raw OTel spans and metrics, bulk insert, and query interfaces
- `otel-retention`: Per-project configurable TTL with Oban-based pruning cron job

### Modified Capabilities

- `error-tracking`: Correlate existing error/exception issues with OTel traces via `trace_id`

### Removed Capabilities

- `telemetry-events-api`: Drop `/api/v1/events` endpoint and GoodIssuesReporter custom format
- `telemetry-spans`: Drop `telemetry_spans` table and `GI.Telemetry` context

## Impact

- **Database**: New `otel_spans` and `otel_metrics` tables; add `otel_service_name` and `retention_days` columns to `projects`; drop `telemetry_spans` table
- **Schemas**: New `GI.Otel.Span`, `GI.Otel.Metric` Ecto schemas; updated `GI.Tracking.Project` with new fields
- **Contexts**: New `GI.Otel` context with storage behaviour; remove `GI.Telemetry` context
- **API**: New OTLP endpoints at `/api/v1/otlp/traces` and `/api/v1/otlp/metrics`; remove `/api/v1/events`
- **Auth**: Add `otel:write` and `otel:read` API key scopes; remove `events:write` and `events:read` scopes
- **Dependencies**: Add `protobuf` hex package; vendor and compile OTLP `.proto` files from `opentelemetry-proto`
- **Workers**: New `GI.Otel.Workers.RetentionPruner` Oban cron job
- **OpenAPI**: Spec updates for new OTLP endpoints (note: protobuf endpoints documented as binary, JSON schema for reference)
