## Why

GoodIssues has a complete error tracking pipeline (Error → Occurrence → StacktraceLine with fingerprint-based dedup), but errors can only be reported through our proprietary REST API. Application teams must write custom integration code to send errors. By accepting the Sentry envelope protocol, any application using an existing Sentry SDK (Elixir, Python, JavaScript, Ruby, Go, Java, etc.) can report exceptions to GoodIssues with a one-line DSN config change — no code changes, no custom client.

## What Changes

- **New Sentry-compatible ingest endpoint** at `POST /api/:sentry_project_id/envelope/` that accepts the Sentry envelope binary format and translates it into `Tracking.report_error/5` calls
- **Sentry auth support** via `X-Sentry-Auth` header parsing — maps `sentry_key` to existing API keys (no new auth model)
- **Numeric project shorthand** (`sentry_id`) added to projects for DSN-compatible URLs (Sentry DSNs use integer project IDs)
- **Multi-exception support** — chained exceptions in a single event each get their own fingerprint and Error record
- **Envelope parser** for Sentry's line-delimited binary format (envelope header + item headers + payloads)
- **Event type routing** — exception events → `report_error`, message events → `report_error` (kind="message"), transaction events → telemetry spans, session/attachment events → ACK silently
- **Rate limiting** on the ingest endpoint using existing rate limiter infrastructure
- **Auto-generated DSN** per project, computed from API key + host + sentry_id

## Capabilities

### New Capabilities
- `sentry-ingest`: Sentry envelope protocol ingestion — parsing, auth translation, event routing, and exception-to-error mapping

### Modified Capabilities
- `error-tracking`: Errors can now originate from Sentry SDKs in addition to the REST API; multi-exception events create multiple Errors per ingest call
- `projects`: Projects gain a `sentry_id` numeric shorthand and a computed DSN for Sentry SDK configuration

## Impact

- **Database**: Migration to add `sentry_id` (integer, unique per account) to `projects` table
- **Router**: New route scope outside `/api/v1/` to match Sentry's expected URL format (`/api/:id/envelope/`)
- **Plugs**: New `SentryAuth` plug to parse `X-Sentry-Auth` header format
- **Phoenix config**: Custom body reader for `application/octet-stream` and `application/x-sentry-envelope` content types
- **Dependencies**: No new dependencies required — envelope parsing is straightforward string/JSON processing
- **Existing APIs**: No breaking changes — all existing REST endpoints remain unchanged
