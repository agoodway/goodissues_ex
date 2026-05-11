## 1. Database & Schema Changes

- [ ] 1.1 Create migration to add `sentry_id` integer column to `projects` table with unique index on `(account_id, sentry_id)`
- [ ] 1.2 Update `Project` schema to include `sentry_id` field
- [ ] 1.3 Update `Project.create_changeset/2` to auto-assign `sentry_id` (next sequential integer within the account)
- [ ] 1.4 Backfill `sentry_id` for existing projects in the migration

## 2. Sentry Envelope Parser

- [ ] 2.1 Create `GI.Sentry.Envelope` module with `parse/1` that accepts binary body and returns `{:ok, envelope_header, items}` or `{:error, reason}`
- [ ] 2.2 Implement item parsing: extract `type`, `length`, and payload for each item in the envelope
- [ ] 2.3 Handle edge cases: malformed JSON, truncated payloads, missing length fields
- [ ] 2.4 Write tests for envelope parsing with valid single-item, multi-item, and malformed envelopes

## 3. Sentry Auth Plug

- [ ] 3.1 Create `GIWeb.Plugs.SentryAuth` plug that parses the `X-Sentry-Auth` header and extracts `sentry_key`
- [ ] 3.2 Implement API key lookup from `sentry_key` value (reuse existing token prefix + hash logic from `ApiAuth`)
- [ ] 3.3 Resolve account, user, and API key assigns on the connection (same assigns as `ApiAuth`)
- [ ] 3.4 Return 401 for missing header, invalid key, revoked/expired key
- [ ] 3.5 Write tests for auth plug with valid keys, missing header, invalid keys, and expired keys

## 4. Sentry Field Translation

- [ ] 4.1 Create `GI.Sentry.Translator` module with `translate_event/1` that converts a Sentry event map into a list of `{error_attrs, occurrence_attrs}` tuples (one per exception)
- [ ] 4.2 Implement exception field mapping: `type` → `kind`, `value` → `reason`, last frame → `source_line`/`source_function`
- [ ] 4.3 Implement stacktrace frame reversal (Sentry oldest-first → GoodIssues crash-site-first) and frame field mapping (`module`, `function`, `filename`/`lineno`, `in_app`)
- [ ] 4.4 Implement context merging: `tags` + `contexts` + `extra` + `user` → `Occurrence.context` map
- [ ] 4.5 Implement breadcrumbs extraction: `breadcrumbs[].message` → `Occurrence.breadcrumbs` string array
- [ ] 4.6 Implement level-to-priority mapping: fatal→critical, error→high, warning→medium, info/debug→low
- [ ] 4.7 Implement fingerprint computation: `SHA256(exception.type <> "|" <> normalized_frames)`
- [ ] 4.8 Implement message-only event translation: kind="message", fingerprint from message template
- [ ] 4.9 Write tests for field translation with single-exception, multi-exception, message-only, and edge cases (missing fields, empty stacktraces)

## 5. Envelope Controller & Routing

- [ ] 5.1 Configure raw body reader for `application/octet-stream` and `application/x-sentry-envelope` content types in Phoenix endpoint
- [ ] 5.2 Create `GIWeb.Sentry.EnvelopeController` with `create/2` action
- [ ] 5.3 Add route `POST /api/:sentry_project_id/envelope/` in router with `sentry_auth` and `api_rate_limited` pipelines
- [ ] 5.4 Implement project lookup by `sentry_id` within the authenticated account
- [ ] 5.5 Implement event routing: exception events → `report_error/5`, message events → `report_error/5`, transaction events → telemetry spans, session/attachment → silent ACK
- [ ] 5.6 Return `{"id": "<event_id>"}` on success, 401 on auth failure, 429 with `Retry-After` on rate limit
- [ ] 5.7 Handle malformed envelopes gracefully (return 200 to prevent retry storms)

## 6. Project API Updates

- [ ] 6.1 Add `sentry_id` to `ProjectJSON` response
- [ ] 6.2 Update OpenAPI schema for project responses to include `sentry_id` field
- [ ] 6.3 Add `get_project_by_sentry_id/2` function to `Tracking` context (account-scoped lookup)

## 7. Integration Tests

- [ ] 7.1 End-to-end test: send a real sentry-elixir-style envelope → verify Issue + Error + Occurrence + StacktraceLines created
- [ ] 7.2 End-to-end test: send duplicate exception → verify Occurrence added to existing Error (no new Issue)
- [ ] 7.3 End-to-end test: send multi-exception event → verify multiple Errors created with independent fingerprints
- [ ] 7.4 End-to-end test: send message-only event → verify Error created with kind="message"
- [ ] 7.5 End-to-end test: send transaction event → verify telemetry span(s) created
- [ ] 7.6 End-to-end test: verify cross-source dedup (REST-created error, then Sentry occurrence of same fingerprint)
- [ ] 7.7 Auth tests: missing header, invalid key, wrong account, rate limiting with Retry-After
