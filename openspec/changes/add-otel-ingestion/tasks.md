## 1. Protobuf Setup

- [ ] 1.1 Add `protobuf` hex dependency to mix.exs
- [ ] 1.2 Vendor OTLP `.proto` files from `opentelemetry-proto` into `app/priv/protos/`
- [ ] 1.3 Generate Elixir proto modules with `protoc --elixir_out` and commit under `app/lib/app/otel/proto/`
- [ ] 1.4 Verify decode/encode roundtrip works for `ExportTraceServiceRequest` and `ExportMetricsServiceRequest` with a basic test
- [ ] 1.5 Add a `Makefile` target or shell script documenting the exact `protoc` invocation used to generate modules, so they can be regenerated when OTLP proto versions change

## 2. Database & Schemas

- [ ] 2.1 Create migration: add `otel_service_name` (varchar, nullable) and `retention_days` (integer, default 30, CHECK >= 1) to `projects` table; add unique index on `(otel_service_name, account_id)` where `otel_service_name IS NOT NULL`
- [ ] 2.2 Create migration: create `otel_spans` table with columns (id binary_id PK, project_id FK, trace_id string, span_id string, parent_span_id string nullable, name string, kind enum, status enum, status_message string nullable, start_time utc_datetime_usec, end_time utc_datetime_usec, attributes jsonb, resource jsonb, events jsonb, links jsonb, instrumentation_scope jsonb, inserted_at utc_datetime); indexes on (project_id, start_time), (trace_id), (project_id, trace_id), GIN(attributes)
- [ ] 2.3 Create migration: create `otel_metrics` table with columns (id binary_id PK, project_id FK, name string, description string nullable, unit string nullable, type enum, is_monotonic boolean nullable, aggregation_temporality enum nullable, resource jsonb, instrumentation_scope jsonb, data_points jsonb, timestamp utc_datetime_usec, inserted_at utc_datetime); indexes on (project_id, name, timestamp), (project_id, timestamp)
- [ ] 2.4 Create migration: drop `telemetry_spans` table
- [ ] 2.5 Create `FF.Otel.Span` Ecto schema with type specs
- [ ] 2.6 Create `FF.Otel.Metric` Ecto schema with type specs
- [ ] 2.7 Update `FF.Tracking.Project` schema with `otel_service_name` and `retention_days` fields; update create/update changesets to cast and validate them (otel_service_name optional, retention_days >= 1)

## 3. Storage Behaviour & Postgres Backend

- [ ] 3.1 Create `FF.Otel.Storage` behaviour with callbacks: `insert_spans/2`, `insert_metrics/2`, `query_spans/2`, `query_metrics/2`, `prune/2`
- [ ] 3.2 Create `FF.Otel.Storage.Postgres` implementing the behaviour — bulk insert via `Repo.insert_all`, query with account scoping, batch delete for prune
- [ ] 3.3 Add config entry `config :app, FF.Otel, storage: FF.Otel.Storage.Postgres`
- [ ] 3.4 Add tests for Postgres storage backend (insert, query, prune)

## 4. Otel Context

- [ ] 4.1 Create `FF.Otel` context module with `ingest_traces/2` and `ingest_metrics/2` functions — accepts account + decoded proto, resolves projects via `otel_service_name`, delegates to storage
- [ ] 4.2 Add `resolve_project_by_service_name/2` to `FF.Tracking` — looks up project by `otel_service_name` within account
- [ ] 4.3 Add normalizer functions to convert proto structs to internal map format (trace_id hex encoding, timestamp nanoseconds → DateTime, attribute lists → maps, etc.)
- [ ] 4.4 Add tests for context functions including project resolution, partial success (some batches rejected), and normalization

## 5. OTLP Controller & Routes

- [ ] 5.1 Create `FFWeb.Api.V1.OtlpController` with `traces/2` and `metrics/2` actions — read raw body via `Plug.Conn.read_body/2`, decode protobuf, call context, respond with proto-encoded response; add max-spans-per-request guard after decoding
- [ ] 5.2 Create `:api_otlp` pipeline in router that accepts `["json", "x-protobuf"]` content types (existing `:api` pipelines reject non-JSON); read body manually, do NOT modify global Plug.Parsers
- [ ] 5.3 Add gzip decompression support for `Content-Encoding: gzip`
- [ ] 5.4 Add routes: `POST /api/v1/otlp/traces` and `POST /api/v1/otlp/metrics`
- [ ] 5.5 Add `otel:write` and `otel:read` to valid API key scopes; remove `events:write` and `events:read`
- [ ] 5.6 Add controller tests (successful ingestion, partial success, auth, invalid protobuf, unknown service name, gzip, private key without `otel:write` scope → 403)
- [ ] 5.7 Update openapi.json with OTLP endpoint documentation

## 6. Retention Pruner

- [ ] 6.1 Create `FF.Otel.Workers.RetentionPruner` Oban cron worker — iterates projects with retention_days set, calls storage.prune for each
- [ ] 6.2 Add cron config: `{"0 3 * * *", FF.Otel.Workers.RetentionPruner}` in Oban config
- [ ] 6.3 Add tests for pruner (prunes old data, respects per-project retention, batch deletion)

## 7. Cleanup

- [ ] 7.1 Remove `FF.Telemetry` context module and `FF.Telemetry.Span` schema (depends on 7.5 and 8.2 completing first — `IssueLive.Show` calls `FF.Telemetry` functions)
- [ ] 7.2 Remove `FFWeb.Api.V1.EventController` and its route
- [ ] 7.3 Remove `events:write` and `events:read` from valid API key scopes (replaced by `otel:write` and `otel:read` in task 5.5)
- [ ] 7.4 Remove telemetry-related tests: `test/app/telemetry_test.exs` (20+ test cases), `test/app_web/controllers/api/v1/event_controller_test.exs` (10 test cases)
- [ ] 7.5 Update `IssueLive.Show` to replace `FF.Telemetry` with `FF.Otel` — change correlation from `request_id` to `trace_id`, update `extract_request_id/1` to extract `trace_id` from occurrence context, replace `:telemetry_spans` assign with `:otel_spans`, update all template helpers (`event_type_class/1`, `event_type_icon/1`, etc.) to work with OTel span `kind` instead of legacy event types

## 8. Error Correlation

- [ ] 8.1 Add `query_spans_by_trace_id/2` to storage behaviour and Postgres implementation
- [ ] 8.2 Update issue detail view to query OTel spans by `trace_id` when available on an issue
- [ ] 8.3 Add tests for trace correlation on issue detail
