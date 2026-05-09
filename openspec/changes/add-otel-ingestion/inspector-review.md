# Inspector Review: add-otel-ingestion

**Date**: 2026-04-29
**Reviewers**: Agent A (structural + consistency), Agent B (codebase alignment + gaps)

## Summary

| Severity | Original | Auto-patched | User-guided | Remaining |
|----------|----------|-------------|-------------|-----------|
| Critical | 5 | 3 | 1 | 1 |
| Warning | 10 | 5 | 3 | 2 |
| Suggestion | 6 | 3 | 0 | 3 |
| **Total** | **21** | **11** | **4** | **6** |

## Remaining findings

### Critical

1. **No delta spec files for new capabilities** — `openspec/changes/add-otel-ingestion/specs/` does not exist. The proposal declares three new capabilities (`otel-ingestion`, `otel-storage`, `otel-retention`) and modifies `error-tracking`, but no spec files define normative requirements (SHALL/MUST scenarios). Without specs, `/opsx:verify` will fail and there is no machine-verifiable contract for implementation. **Action**: Create `specs/otel-ingestion/spec.md`, `specs/otel-storage/spec.md`, `specs/otel-retention/spec.md`, and `specs/error-tracking/spec.md` (delta) with ADDED/MODIFIED Requirements sections.

### Warning

1. **OTLP route pipeline and auth model unclear** — `router.ex:133`: the existing events route uses `:api_write` pipeline which enforces `require_write_access` (private key check) then scope-based auth. The spec does not define which pipeline OTLP routes belong to or whether both checks are needed. The design now mentions a new `:api_otlp` pipeline but doesn't specify whether it includes `require_write_access`. **Action**: Define the full OTLP pipeline in the design — recommend reusing the `:api_write` pattern (private key required + scope check) for consistency.

2. **Project validation responsibility unclear** — `telemetry.ex:57`: existing `create_spans_batch_unchecked/2` skips N+1 validation. The storage behaviour doesn't specify whether `GI.Otel` context validates project ownership before calling `Storage.insert_spans/2`, or whether each adapter handles it. **Action**: Clarify in design.md that the context resolves and validates the project, and the storage adapter receives a guaranteed-valid `project_id`.

### Suggestion

1. **No observability for ingestion pipeline** — No telemetry events or structured logging are planned for OTLP ingestion (span count, decode errors, insert latency). Consider adding `:telemetry` events in the controller and storage adapter.

2. **Total rejection HTTP status unspecified** — The design covers partial success but not the case when ALL ResourceSpans batches are rejected (every service.name unknown). Recommend HTTP 400 with structured error body rather than HTTP 200 with all-rejected.

3. **OpenAPI for protobuf endpoints** — Task 5.7 says "update openapi.json" but the OTLP protocol uses protobuf. Determine whether OTLP endpoints should appear in the OpenAPI spec at all, or document them with a minimal schema noting binary protobuf bodies. The existing `GIWeb.ApiSpec` module uses JSON exclusively.

## Patches applied

11 findings were auto-patched. 4 findings were patched after user guidance. 0 findings were skipped.

### Auto-patched

1. **Missing `query_spans_by_trace_id` in storage behaviour** — `design.md:164` → Added `@callback query_spans_by_trace_id/2` to the behaviour definition to match task 8.1
2. **Single migration for creates + drops** — `design.md:256` → Split into two migrations (add OTel tables, then drop legacy) for safe rollback
3. **Missing CHECK constraint on retention_days** — `design.md:141` → Added `CHECK (retention_days >= 1)` to the ALTER TABLE statement and task 2.1
4. **Phoenix content-type negotiation blocks protobuf** — `design.md:181` → Added "Phoenix Integration Notes" section documenting need for `:api_otlp` pipeline and `Plug.Conn.read_body` pattern
5. **Oban cron config missing** — `design.md:181` → Added cron plugin config to Phoenix Integration Notes
6. **No supersession marker for add-telemetry-events-api** — `proposal.md:1` → Added `## Supersedes` section listing both superseded changes
7. **No protoc generation script task** — `tasks.md:5` → Added task 1.5 for Makefile/script documenting protoc invocation
8. **Task 7.1 ordering dependency** — `tasks.md:51` → Added dependency note that 7.1 requires 7.5 and 8.2 first
9. **Test file references in cleanup** — `tasks.md:54` → Made task 7.4 explicit about which test files and their scope
10. **Missing auth test case** — `tasks.md:40` → Added private-key-without-scope test case to task 5.6
11. **Controller body reading and pipeline** — `tasks.md:35-36` → Updated tasks 5.1 and 5.2 to specify `Plug.Conn.read_body`, `:api_otlp` pipeline, and max-spans guard

### User-guided patches

1. **Correlation mechanism: trace_id vs request_id** — `tasks.md:55` → Updated task 7.5 with explicit trace_id correlation, template helper updates, and assign rename (user chose: correlate by trace_id, clean break)
2. **JSON content-type support scope** — `design.md:60` → Changed "Optionally support application/json" to "Not supported in v1 — protobuf only" (user chose: not in v1)
3. **retention_days nullable vs non-nullable** — `design.md:234` → Updated pruner comment to "retention_days is always present, default 30" (user chose: always-present)
4. **API key scopes replacement** — `proposal.md:47`, `tasks.md:39,53` → Added `otel:read`, removed `events:read` alongside `events:write` (user chose: add otel:read, drop both events scopes)

## Verdict

**Needs revision** — The missing delta spec files (Critical) must be created before this change can proceed to implementation. The remaining Warning and Suggestion items should be addressed in the specs or design but are not blockers.
