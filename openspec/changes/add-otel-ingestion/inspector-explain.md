# Explain — add-otel-ingestion

**Generated:** 2026-05-12

## TL;DR

Replace GoodIssues's custom telemetry system with standard OpenTelemetry Protocol (OTLP) ingestion. Any app with an OTel SDK — in any language — can send traces and metrics to GoodIssues. The old `telemetry_spans` table, `GI.Telemetry` context, and `/api/v1/events` endpoint are removed entirely.

## Context — Why this change exists

GoodIssues currently has a custom telemetry system that only works with Elixir/Phoenix apps via a proprietary reporter format. This limits adoption to one ecosystem. OpenTelemetry is the industry standard for observability — every major language has an SDK. By accepting OTLP HTTP/protobuf natively, GoodIssues becomes a universal telemetry backend. Users just configure their existing OTel exporter to point at GoodIssues and get traces + metrics correlated with their error tracking.

## What changes

### Data / Schema

```
BEFORE:                              AFTER:
┌──────────────────┐                 ┌──────────────────┐
│ projects         │                 │ projects (changed)│
├──────────────────┤                 ├──────────────────┤
│ id               │                 │ id               │
│ name             │                 │ name             │
│ prefix           │                 │ prefix           │
│ account_id (FK)  │                 │ account_id (FK)  │
└────────┬─────────┘                 │ otel_service_name│ (new)
         │                           │ retention_days   │ (new, default 30)
         │ has_many                   └────────┬─────────┘
         │                                     │
┌────────┴─────────┐                           │ has_many
│ telemetry_spans  │ ← DROPPED                 │
├──────────────────┤                 ┌─────────┴────────┐
│ id               │                 │ otel_spans (new) │
│ project_id       │                 ├──────────────────┤
│ request_id       │                 │ id               │
│ trace_id         │                 │ project_id (FK)  │
│ event_type       │                 │ trace_id (32 hex)│
│ event_name       │                 │ span_id (16 hex) │
│ timestamp        │                 │ parent_span_id   │
│ duration_ms      │                 │ name             │
│ context (json)   │                 │ kind (enum)      │
│ measurements     │                 │ status (enum)    │
└──────────────────┘                 │ start_time (usec)│
                                     │ end_time (usec)  │
                                     │ attributes (jsonb)
                                     │ resource (jsonb) │
                                     │ events (jsonb)   │
                                     │ links (jsonb)    │
                                     │ instr_scope(jsonb)
                                     └──────────────────┘

                                     ┌──────────────────┐
                                     │otel_metrics (new)│
                                     ├──────────────────┤
                                     │ id               │
                                     │ project_id (FK)  │
                                     │ name             │
                                     │ type (enum)      │
                                     │ data_points(jsonb)
                                     │ resource (jsonb) │
                                     │ timestamp (usec) │
                                     └──────────────────┘
```

Key data model decisions:
- `trace_id` / `span_id` stored as hex strings for readability
- `data_points` is JSONB because metric shapes vary wildly (gauges vs histograms vs summaries)
- `otel_service_name` on projects maps OTLP `service.name` → project, unique per account

### System / Architecture

```
                    BEFORE

  Elixir App                GoodIssues
  ┌──────────┐              ┌─────────────────┐
  │ GoodIssues              │                 │
  │ Reporter │──── JSON ───▶│ EventController │
  │ (custom) │  POST /api/  │ /events/batch   │
  └──────────┘  v1/events/  ├─────────────────┤
                batch       │ GI.Telemetry    │
                            │ (context)       │
                            ├─────────────────┤
                            │ telemetry_spans │
                            └─────────────────┘

                    AFTER

  Any App (any language)    GoodIssues
  ┌──────────┐              ┌─────────────────┐
  │ OTel SDK │              │ OtlpController  │
  │ (Go, Py, │── protobuf ─▶│ /otlp/traces   │
  │  JS, Rust,│  POST /api/ │ /otlp/metrics   │
  │  Elixir) │  v1/otlp/*  ├────────┬────────┤
  └──────────┘  + Bearer    │ GI.Otel│Normaliz│
                sk_...      │(context│  proto │
                            │  +     │→ maps) │
                            │ resolve│        │
                            │ project│        │
                            ├────────┴────────┤
                            │ GI.Otel.Storage │
                            │   (behaviour)   │
                            ├─────────────────┤
                            │ Postgres (v1)   │
                            │ ┌─────────────┐ │
                            │ │ otel_spans  │ │
                            │ │ otel_metrics│ │
                            │ └─────────────┘ │
                            └─────────────────┘
```

### Ingestion flow (trace)

```
OTLP HTTP request arrives
         │
         ▼
┌──────────────────┐
│ Read raw body    │  (protobuf binary,
│ Decompress gzip  │   optionally gzipped)
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Decode protobuf  │  ExportTraceServiceRequest
│ → ResourceSpans[]│
└────────┬─────────┘
         │
         ▼ for each ResourceSpans
┌──────────────────┐
│ Extract          │  resource.attributes
│ "service.name"   │  → "my-web-app"
└────────┬─────────┘
         │
         ▼
┌──────────────────┐     ┌─────────┐
│ Resolve project  │────▶│ SELECT  │
│ by service_name  │     │ project │
│ within account   │     │ WHERE   │
└────────┬─────────┘     │ svc_name│
         │               │ = ? AND │
    found│  not found    │ acct_id │
         │     │         │ = ?     │
         ▼     ▼         └─────────┘
   ┌──────┐  ┌───────┐
   │Insert│  │Reject │
   │spans │  │batch  │
   │      │  │(count)│
   └──────┘  └───────┘
         │
         ▼
┌──────────────────┐
│ Return proto     │  ExportTraceServiceResponse
│ response (200)   │  { rejected_spans: N }
└──────────────────┘
```

### Retention pruning

```
Daily Oban cron (3:00 AM)
         │
         ▼
┌──────────────────────────────┐
│ RetentionPruner              │
│                              │
│ for each project:            │
│   cutoff = now - retention   │
│   days (default: 30)         │
│                              │
│   DELETE otel_spans          │
│   WHERE start_time < cutoff  │
│   (in batches of 1000)       │
│                              │
│   DELETE otel_metrics        │
│   WHERE timestamp < cutoff   │
│   (in batches of 1000)       │
└──────────────────────────────┘
```

### Error ↔ Trace correlation

```
┌──────────────────┐      ┌──────────────┐
│ Issue (exception)│      │ OTel Span    │
├──────────────────┤      ├──────────────┤
│ trace_id ────────┼─────▶│ trace_id     │
│ kind             │      │ status: ERROR│
│ reason           │      │ attributes   │
│ stacktrace       │      │ start_time   │
└──────────────────┘      │ end_time     │
                          └──────────────┘

Issue detail view queries otel_spans
by trace_id to show the full request
trace alongside the exception.
```

### Logic / Behavior

**Storage behaviour pattern** — `GI.Otel.Storage` defines a behaviour (interface) that abstracts the storage engine. V1 ships with Postgres. Future adapters (ClickHouse, BigQuery) can be swapped via config without changing any upstream code.

```
GI.Otel (context)
    │
    │ calls storage()
    ▼
GI.Otel.Storage (behaviour)
    │
    ├── GI.Otel.Storage.Postgres  ← v1 (now)
    ├── GI.Otel.Storage.ClickHouse ← future
    └── GI.Otel.Storage.BigQuery   ← future
```

**Auth scopes** — `events:write` / `events:read` are removed and replaced with `otel:write` / `otel:read`.

## Implementation path

1. **Protobuf setup** — Add `protobuf` dep, vendor `.proto` files, generate Elixir modules, verify roundtrip
2. **Migrations & schemas** — Add project fields, create `otel_spans` + `otel_metrics` tables, drop `telemetry_spans`
3. **Storage behaviour** — Define `GI.Otel.Storage` behaviour, implement Postgres backend with bulk insert/query/prune
4. **OTel context** — `GI.Otel` with proto→map normalization, project resolution via `otel_service_name`, partial success handling
5. **OTLP controller & routes** — Raw body reading, protobuf decode, gzip support, new `:api_otlp` pipeline, `otel:write` scope
6. **Retention pruner** — Daily Oban cron, per-project TTL, batch deletion
7. **Cleanup** — Remove `GI.Telemetry`, `EventController`, legacy routes, legacy scopes, update `IssueLive.Show`
8. **Error correlation** — `query_spans_by_trace_id`, update issue detail view

## Risks & trade-offs

- **HTTP/protobuf only, no gRPC** — Phoenix isn't a natural gRPC host. This covers the Elixir SDK default and all major OTel SDKs, but gRPC-only clients would need a proxy.
- **Postgres for time-series data** — Postgres is good enough for moderate volume but won't scale to high-throughput production tracing. The storage behaviour makes backend swapping straightforward when needed.
- **No JSON OTLP in v1** — Only `application/x-protobuf` is accepted. JSON OTLP support can be added later.
- **No data migration from legacy** — Telemetry data is treated as ephemeral. The `telemetry_spans` table is dropped without migrating contents.
- **Batch deletion for retention** — Avoids table locks but means pruning large backlogs takes multiple cycles.

## Open questions

- None identified in the artifacts.
