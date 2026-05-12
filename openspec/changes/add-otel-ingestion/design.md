## Architecture

### System Overview

```
Client App (any language)
  │
  │ OTLP HTTP/protobuf
  │ POST /api/v1/otlp/traces
  │ POST /api/v1/otlp/metrics
  │ Authorization: Bearer sk_...
  │ Content-Type: application/x-protobuf
  │
  ▼
┌─────────────────────────────────────────────────┐
│  GIWeb.Api.V1.OtlpController                    │
│  ├── Read raw body (protobuf binary)            │
│  ├── Decode via generated proto modules         │
│  └── Delegate to GI.Otel context                │
└──────────────────────┬──────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────┐
│  GI.Otel (context)                              │
│  ├── Normalize proto structs → internal maps    │
│  ├── Resolve project via otel_service_name      │
│  │   (reject if project not found)              │
│  └── Delegate to storage backend                │
└──────────────────────┬──────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────┐
│  GI.Otel.Storage (behaviour)                    │
│                                                 │
│  GI.Otel.Storage.Postgres (v1 impl)             │
│  ├── Bulk insert otel_spans via insert_all      │
│  ├── Bulk insert otel_metrics via insert_all    │
│  └── Query with account scoping                 │
└─────────────────────────────────────────────────┘
```

### Protobuf Strategy

Vendor `.proto` files from `opentelemetry-proto` repository into `app/priv/protos/`. Generate Elixir modules using `protoc --elixir_out` with the `protobuf` hex package. Commit generated modules under `app/lib/good_issues/otel/proto/` — they are stable and tied to the OTLP spec version.

Required proto files:
- `opentelemetry/proto/collector/trace/v1/trace_service.proto`
- `opentelemetry/proto/collector/metrics/v1/metrics_service.proto`
- `opentelemetry/proto/trace/v1/trace.proto`
- `opentelemetry/proto/metrics/v1/metrics.proto`
- `opentelemetry/proto/common/v1/common.proto`
- `opentelemetry/proto/resource/v1/resource.proto`

### Decision: HTTP/protobuf only, no gRPC

Phoenix is not a natural gRPC host. HTTP/protobuf is the default for the Elixir OTel SDK and is supported by all major OTel SDKs. Adding gRPC would require a separate listener and the `grpc` hex package. Not worth the complexity for v1.

### Decision: Content-Type negotiation

Accept `application/x-protobuf` (required). JSON content-type is not supported in v1 — protobuf only.

Support `Content-Encoding: gzip` for compressed payloads.

## Data Model

### otel_spans

```
┌─────────────────────────────────────────────────────┐
│ otel_spans                                          │
├──────────────────────┬──────────────────────────────┤
│ id                   │ binary_id (PK)               │
│ project_id           │ FK → projects                │
│ trace_id             │ string (32 hex chars)         │
│ span_id              │ string (16 hex chars)         │
│ parent_span_id       │ string (nullable)             │
│ name                 │ string                        │
│ kind                 │ enum: server, client,         │
│                      │   internal, producer,         │
│                      │   consumer, unspecified        │
│ status               │ enum: unset, ok, error        │
│ status_message       │ string (nullable)             │
│ start_time           │ utc_datetime_usec             │
│ end_time             │ utc_datetime_usec             │
│ attributes           │ jsonb (default: {})           │
│ resource             │ jsonb (default: {})           │
│ events               │ jsonb (default: [])           │
│ links                │ jsonb (default: [])           │
│ instrumentation_scope│ jsonb (default: {})           │
│ inserted_at          │ utc_datetime                  │
├──────────────────────┴──────────────────────────────┤
│ Indexes:                                            │
│   (project_id, start_time)                          │
│   (trace_id)                                        │
│   (project_id, trace_id)                            │
│   GIN(attributes)                                   │
└─────────────────────────────────────────────────────┘
```

### Decision: trace_id/span_id as hex strings

OTel IDs are 16-byte (trace) and 8-byte (span) binaries. Store as hex strings for readability in queries, logs, and JSON responses. The 2x storage cost is negligible vs the debugging ergonomics.

### otel_metrics

```
┌─────────────────────────────────────────────────────┐
│ otel_metrics                                        │
├──────────────────────┬──────────────────────────────┤
│ id                   │ binary_id (PK)               │
│ project_id           │ FK → projects                │
│ name                 │ string                        │
│ description          │ string (nullable)             │
│ unit                 │ string (nullable)             │
│ type                 │ enum: gauge, sum, histogram,  │
│                      │   exponential_histogram,      │
│                      │   summary                     │
│ is_monotonic         │ boolean (nullable)            │
│ aggregation_temporality │ enum: unspecified, delta,  │
│                      │   cumulative (nullable)       │
│ resource             │ jsonb (default: {})           │
│ instrumentation_scope│ jsonb (default: {})           │
│ data_points          │ jsonb                         │
│ timestamp            │ utc_datetime_usec             │
│ inserted_at          │ utc_datetime                  │
├──────────────────────┴──────────────────────────────┤
│ Indexes:                                            │
│   (project_id, name, timestamp)                     │
│   (project_id, timestamp)                           │
└─────────────────────────────────────────────────────┘
```

### Decision: data_points as JSONB

Metric data points vary wildly by type — gauges have a value, histograms have bucket_counts + explicit_bounds + sum + count, exponential histograms have scale + positive/negative buckets. JSONB accommodates all shapes without schema sprawl. When moving to ClickHouse or BigQuery, the backend can denormalize into typed columns — that's the backend adapter's concern.

### projects table additions

```
ALTER TABLE projects ADD COLUMN otel_service_name varchar;
ALTER TABLE projects ADD COLUMN retention_days integer DEFAULT 30 CHECK (retention_days >= 1);
CREATE UNIQUE INDEX projects_otel_service_name_account_id ON projects (otel_service_name, account_id) WHERE otel_service_name IS NOT NULL;
```

- `otel_service_name`: stable identifier for OTLP project resolution, unique per account
- `retention_days`: TTL for OTel data pruning, default 30 days

## Storage Behaviour

```elixir
defmodule GI.Otel.Storage do
  @type span_params :: map()
  @type metric_params :: map()
  @type filter :: keyword()

  @callback insert_spans(project_id :: String.t(), spans :: [span_params()]) ::
              {:ok, non_neg_integer()} | {:error, term()}
  @callback insert_metrics(project_id :: String.t(), metrics :: [metric_params()]) ::
              {:ok, non_neg_integer()} | {:error, term()}
  @callback query_spans(project_id :: String.t(), filters :: filter()) ::
              {:ok, [map()]}
  @callback query_metrics(project_id :: String.t(), filters :: filter()) ::
              {:ok, [map()]}
  @callback prune(project_id :: String.t(), older_than :: DateTime.t()) ::
              {:ok, non_neg_integer()}
  @callback query_spans_by_trace_id(project_id :: String.t(), trace_id :: String.t()) ::
              {:ok, [map()]}
end
```

Configuration:
```elixir
config :good_issues, GI.Otel, storage: GI.Otel.Storage.Postgres
```

The context reads the adapter at runtime:
```elixir
defp storage, do: Application.get_env(:app, GI.Otel)[:storage]
```

## OTLP Receiver Flow

### Phoenix Integration Notes

**Content-Type negotiation**: The existing API pipelines declare `plug :accepts, ["json"]`, which rejects `application/x-protobuf` with 406 Not Acceptable. OTLP routes need a separate pipeline (`:api_otlp`) that accepts `["json", "x-protobuf"]` or uses a wildcard.

**Body reading**: `Plug.Parsers` only handles `[:urlencoded, :multipart, :json]`. The OtlpController must read the raw body via `Plug.Conn.read_body(conn, length: <limit>)` and decode the protobuf manually. Do NOT add a custom parser to the global endpoint.

**Oban cron config**: The existing Oban config already has an `Oban.Plugins.Cron` plugin with `Reaper` and `HeartbeatRecovery` entries. Add `{"0 3 * * *", GI.Otel.Workers.RetentionPruner}` to the existing `crontab` list. The pruner uses the existing `:maintenance` queue.

### Trace ingestion

1. Controller reads raw body via `Plug.Conn.read_body(conn)`
2. Decode `ExportTraceServiceRequest` protobuf
3. Extract `resource_spans` → for each ResourceSpans:
   a. Read `resource.attributes` → find `service.name`
   b. Resolve project via `otel_service_name` within account
   c. If project not found → collect error, skip this batch
   d. Flatten Span structs → internal map format
4. Bulk insert via storage backend
5. Respond with `ExportTraceServiceResponse` (include `rejected_spans` count if any)

### Metric ingestion

Same flow but with `ExportMetricsServiceRequest` → `resource_metrics` → data points.

### Auth

Same Bearer token pipeline as existing API. The API key scopes to an account. New scope: `otel:write`.

### Project resolution

```
OTLP request arrives with Bearer sk_... → account resolved
  │
  ▼
resource.attributes["service.name"] = "my-web-app"
  │
  ▼
SELECT id FROM projects
WHERE account_id = $1 AND otel_service_name = $2
  │
  ├── Found → insert spans/metrics for this project
  └── Not found → reject this ResourceSpans batch, continue others
```

Multiple services can appear in a single OTLP request (multiple ResourceSpans entries). Each is resolved independently. Partial success is supported — some batches succeed, others rejected.

## Retention Pruner

Oban cron worker running daily (configurable):

```elixir
defmodule GI.Otel.Workers.RetentionPruner do
  use Oban.Worker, queue: :maintenance

  # Configured as cron: [{"0 3 * * *", GI.Otel.Workers.RetentionPruner}]

  @impl Oban.Worker
  def perform(_job) do
    # For each project (retention_days is always present, default 30):
    # 1. Calculate cutoff = now - retention_days
    # 2. Delete in batches (1000 rows per batch) to avoid long locks
    # 3. Log pruned counts
  end
end
```

Batch deletion avoids table-level locks on large deletes. Uses `DELETE ... WHERE id IN (SELECT id ... LIMIT 1000)` pattern.

## Correlation with Error Tracking

GoodIssuesReporter sends exceptions as issues. OTel traces carry `trace_id`. When both are present for the same request:

```
Issue (exception)              OTel Span
├── request_id ───────────── attributes["http.request_id"]
├── trace_id   ───────────── trace_id
└── timestamp  ───────────── span with status: ERROR
```

The issue detail view can query `otel_spans` by `trace_id` to show the full request trace alongside the exception. This is a read-path concern, not part of the ingestion pipeline.

## Migration Strategy

Two migrations, sequenced for safe rollback:

**Migration 1 — Add OTel tables and project columns:**
1. Creates `otel_spans` table with indexes
2. Creates `otel_metrics` table with indexes
3. Adds `otel_service_name` and `retention_days` (with `CHECK (retention_days >= 1)`) to `projects`

**Migration 2 — Drop legacy telemetry:**
4. Drops `telemetry_spans` table

Splitting the drop into a separate migration allows rolling back the OTel tables without losing the legacy table. This is a clean break — no data migration needed since telemetry data is ephemeral.

## Future Backend Adapters

The storage behaviour makes backend swapping straightforward:

| Backend | Strengths | When |
|---------|-----------|------|
| Postgres | Simple, already have it, good enough for moderate volume | v1 (now) |
| ClickHouse | Columnar storage, excellent for time-series queries at scale | When query perf on large datasets matters |
| BigQuery | Managed, good for analytics-heavy workloads | When users need long-term retention + analytics |

Each adapter implements the same behaviour. The Ecto schemas are Postgres-specific — alternative adapters use their own query/insert mechanisms.
