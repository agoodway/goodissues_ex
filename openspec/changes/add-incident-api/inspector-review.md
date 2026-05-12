# Inspector Review: add-incident-api

## Summary

Original findings: 1 Critical, 7 Warning, 1 Suggestion.

Verdict: ready after review-update patches.

## Findings

No unresolved findings remain.

## Patches applied

9 findings were patched. 7 findings were auto-patched. 2 findings were patched after user guidance. 0 findings were skipped.

### Auto-patched

1. **Use implementable account-scoped uniqueness** — `tasks.md:3`, `specs/incident-api/spec.md:4` → Added `account_id` to incidents, changed the migration task to `unique_index(:incidents, [:account_id, :fingerprint])`, and documented why PostgreSQL cannot enforce uniqueness through the issue/project join in `design.md:89`.
2. **Clarify `report_incident/5` reopen-window input** — `design.md:47`, `specs/incident-api/spec.md:27`, `tasks.md:15` → Kept the `/5` function signature and specified that `reopen_window_hours` is an optional `incident_attrs` key with a 24-hour default.
3. **Set incident status back to unresolved on reopen/new issue** — `specs/incident-api/spec.md:43`, `specs/incident-api/spec.md:53` → Added requirements that reopened incidents and outside-window new issues set incident status to `:unresolved`.
4. **Avoid active `error-tracking` scenario collisions** — `specs/error-tracking/spec.md:1` → Converted the change from modifying `Error API Endpoints` search/list scenarios to adding a separate `Shared error dedup mechanics` requirement, avoiding conflicts with `sentry-ingest-endpoint` and `add-otel-ingestion`.
5. **Preserve monitoring lifecycle cleanup** — `design.md:61`, `tasks.md:32`, `tasks.md:33` → Added explicit requirements to preserve check/heartbeat status cleanup, `current_issue_id` clearing, and result/ping issue linkage after calling `resolve_incident/2`.
6. **Cover new API scopes and validation risks** — `tasks.md:45`, `tasks.md:46` → Added tests for account isolation, advisory-lock concurrency, validation failures, pagination bounds, malformed IDs, forbidden scopes, write-scope denial, and project/account isolation.
7. **Reuse existing lock-key helper accurately** — `tasks.md:13` → Updated the dedup extraction task to reuse the existing `fingerprint_lock_key/2` instead of implying it must be newly extracted.

### User-guided patches

1. **Clarify outside-window incident identity** — `design.md:41`, `specs/incident-api/spec.md:53` → User chose one long-lived aggregate incident per `(account_id, fingerprint)`; documented that outside-window recurrence creates a new issue and updates the existing incident's `issue_id`.
2. **Restrict PATCH lifecycle semantics** — `proposal.md:11`, `design.md:75`, `tasks.md:20`, `specs/incident-api/spec.md:99` → User chose PATCH muting only; updated tasks and specs to reject `status` updates with 400 so status remains governed by `report_incident/5` and `resolve_incident/2`.

### Skipped

None.

## Review Notes

- Other active changes touching `error-tracking`: `add-otel-ingestion` and `sentry-ingest-endpoint`.
- The change directory was untracked at review time (`?? openspec/changes/add-incident-api/`).
- Source code was not modified; this review-update only edited OpenSpec artifacts and wrote this report.
