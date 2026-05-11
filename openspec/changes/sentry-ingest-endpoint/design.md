## Context

GoodIssues has a complete error tracking pipeline: `Error → Occurrence → StacktraceLine` with SHA256 fingerprint-based deduplication and PostgreSQL advisory locks for concurrency safety. The existing `Tracking.report_error/5` function handles the full create-or-append flow.

Sentry SDKs (available for every major language) send exceptions using an envelope protocol over HTTP. The SDK constructs a POST URL from a DSN string: `https://{key}@{host}/{project_id}` → `POST {host}/api/{project_id}/envelope/`. Auth is via an `X-Sentry-Auth` header containing the key.

The goal is to accept this protocol directly so any Sentry SDK can report to GoodIssues with a DSN config change.

## Goals / Non-Goals

**Goals:**
- Accept the Sentry envelope protocol from any Sentry SDK
- Translate Sentry exceptions into `report_error/5` calls with no data loss
- Support multi-exception events (chained errors), each with independent fingerprinting
- Route non-exception event types (transactions, messages, sessions) appropriately
- Reuse existing auth (API keys) and error tracking infrastructure
- Auto-generate DSNs per project

**Non-Goals:**
- Full Sentry server compatibility (project creation API, release tracking, source maps, etc.)
- Sentry web UI compatibility or Sentry relay protocol
- Custom Sentry SDK modifications — standard SDKs must work unmodified
- Storing raw envelope payloads for replay
- Performance monitoring dashboards (transaction data is stored but not visualized)

## Decisions

### 1. Route outside `/api/v1/` to match Sentry URL format

Sentry SDKs construct `POST /api/{project_id}/envelope/` from the DSN. This URL format is hardcoded in every SDK.

**Decision**: Mount the endpoint at `POST /api/:sentry_project_id/envelope/` in a dedicated router scope, outside the `/api/v1/` namespace.

**Alternative considered**: Prefix with `/sentry/api/:id/envelope/` to namespace it. Rejected because it would require SDK-side URL overrides, defeating the zero-config goal.

### 2. Map `sentry_key` to existing API keys

The `X-Sentry-Auth` header contains `sentry_key=<value>`. Rather than creating a new auth model, the sentry_key value IS an existing API key token (e.g., `sk_abc123`).

**Decision**: New `SentryAuth` plug parses the `X-Sentry-Auth` header, extracts `sentry_key`, and performs the same lookup as `ApiAuth` (prefix extraction → hash → DB lookup → account resolution).

**Alternative considered**: Create a dedicated "DSN key" model. Rejected because it adds complexity with no benefit — API keys already have scoping, expiry, and revocation.

### 3. Numeric `sentry_id` on projects for DSN compatibility

Sentry DSNs use integer project IDs in the URL path. GoodIssues uses UUIDs.

**Decision**: Add `sentry_id` integer column to projects, auto-assigned on creation. Unique per account (not globally). The DSN is computed: `https://{api_key}@{host}/{sentry_id}`.

**Implementation**: Use a DB sequence or `MAX(sentry_id) + 1` within the account at creation time. The value is immutable after creation.

**Alternative considered**: Use a global sequence. Rejected because per-account scoping keeps IDs small and predictable (project 1, 2, 3...).

### 4. Envelope parsing as a dedicated module

The Sentry envelope format is line-delimited: JSON header, then pairs of (item-header, item-payload). The `length` field in item headers defines payload byte size.

**Decision**: `GI.Sentry.Envelope` module handles binary parsing. Returns a list of typed items (`{:event, map}`, `{:transaction, map}`, `{:session, map}`, etc.). Unknown item types are silently ignored.

**Key detail**: Phoenix default body parsers reject non-JSON content types. A custom `Plug.Parsers` configuration or raw body reader is needed since envelopes arrive as `application/octet-stream` or `application/x-sentry-envelope`.

### 5. One Error per exception in multi-exception events

Sentry events can contain multiple chained exceptions (e.g., `RuntimeError` caused by `DBConnection.ConnectionError`).

**Decision**: Iterate `event.exception[]`, compute an independent fingerprint per exception, and call `report_error/5` for each. Shared event context (tags, user, environment, breadcrumbs) is attached to every Occurrence.

**Trade-off**: This means a single SDK event can create multiple Issues. The benefit is each root cause tracks independently — you see which underlying errors are most frequent.

### 6. Fingerprint computation

**Decision**: `SHA256(exception.type <> "|" <> normalized_frames)` where normalized frames are `module.function/arity:line` joined by `|`, using only the top N frames (configurable, default all). File paths are excluded (they change across deploys).

For message events (no exception): `SHA256("message|" <> message_template)`.

### 7. Stacktrace frame ordering

Sentry sends frames oldest-first (index 0 = outermost caller, last index = crash site). GoodIssues `StacktraceLine.position` 0 should be the crash site (most relevant frame first).

**Decision**: Reverse the Sentry frame array before storing. `source_line` and `source_function` on the Error are derived from the last Sentry frame (the crash site).

### 8. Event type routing

| Sentry Item Type | Action |
|---|---|
| `event` with `exception[]` | `report_error/5` per exception |
| `event` with `message` only | `report_error/5` with kind="message" |
| `transaction` | Create telemetry Span(s) via `Telemetry.create_spans/2` |
| `session` | ACK silently (return 200, no storage) |
| `attachment` | ACK silently |
| `client_report` | ACK silently |

### 9. Sentry-level field mapping

| Sentry Field | GoodIssues Target |
|---|---|
| `exception[].type` | `Error.kind` |
| `exception[].value` | `Error.reason`, `Occurrence.reason` |
| Last frame `file:lineno` | `Error.source_line` |
| Last frame `module.function` | `Error.source_function` |
| Computed SHA256 | `Error.fingerprint` |
| `exception[].stacktrace.frames[]` | `StacktraceLine` rows (reversed) |
| `tags`, `contexts`, `extra`, `user` | `Occurrence.context` (merged map) |
| `breadcrumbs[].message` | `Occurrence.breadcrumbs` (string array) |
| `level` | `Issue.priority` (fatal→critical, error→high, warning→medium, info/debug→low) |
| `environment` | `Occurrence.context.environment` |
| `timestamp` | `Error.last_occurrence_at` |

### 10. Response format

Sentry SDKs expect minimal responses:
- **200**: `{"id": "<event_id>"}` — SDKs use this to confirm delivery
- **401**: Auth failure — SDKs will not retry
- **429**: Rate limited — SDKs respect `Retry-After` header and back off

## Risks / Trade-offs

**[Envelope parsing edge cases]** → The envelope format allows binary attachments with `length` headers. Malformed envelopes (wrong length, truncated) could cause parsing failures. → Mitigation: Parse defensively, skip malformed items, still ACK the envelope with 200 to prevent SDK retry storms.

**[High-cardinality fingerprints]** → If exception messages contain unique data (request IDs, timestamps), every occurrence gets a unique fingerprint, creating unbounded Issues. → Mitigation: Fingerprint uses type + stacktrace only (not the message/value). This matches Sentry's own default grouping.

**[Rate limiting under burst]** → Error spikes (e.g., deployment breaks everything) can send thousands of events per second. → Mitigation: Use existing rate limiter. SDKs respect 429 + Retry-After and have built-in client-side rate limiting. The existing 60req/60s limit may need tuning for this endpoint.

**[Route collision]** → `POST /api/:sentry_project_id/envelope/` could collide with `/api/v1/...` if sentry_project_id = "v1". → Mitigation: `sentry_project_id` is always an integer. Add a plug guard that rejects non-integer values, or use a route constraint.

**[Multi-exception transaction overhead]** → An event with 5 chained exceptions triggers 5 `report_error/5` calls, each with an advisory lock and potential Issue creation. → Mitigation: Wrap the entire event processing in a single transaction where possible, or accept the overhead since chained exceptions rarely exceed 3-4 levels.

## Open Questions

- **Rate limit tuning**: Should the Sentry endpoint have different rate limits than the REST API? Error bursts are common during incidents.
- **DSN display**: Where in the UI is the DSN shown? Project settings page? A dedicated "Integrations" tab?
- **Transaction → Span mapping**: The Sentry transaction format differs from the existing telemetry Span model. Should this be a best-effort mapping in v1 or deferred?
