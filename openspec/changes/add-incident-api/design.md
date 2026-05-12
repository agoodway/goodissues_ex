## Context

GoodIssues has error tracking with fingerprint-based dedup (advisory locks, find-or-create, occurrences). The monitoring subsystem creates incident issues through its own lifecycle modules that talk directly to `Tracking.create_issue` and `Tracking.update_issue`, bypassing dedup machinery. The `goodissues_reporter` SystemMonitor currently misuses the error API for resource threshold breaches.

This change introduces a first-class incident API that unifies these paths: external reporters, internal monitoring, and the API all flow through a single `report_incident/5` function with the same advisory-lock dedup pattern used by errors.

## Goals / Non-Goals

**Goals:**
- Dedicated incident schema with caller-provided fingerprints, severity, source, and metadata
- Incident occurrence tracking (separate from error occurrences)
- Advisory-lock dedup with reopen-window semantics for incidents
- REST API for reporting, listing, and managing incidents
- Monitoring lifecycle modules refactored to use `report_incident/5` and `resolve_incident/2`
- Shared dedup pattern extracted from `report_error/5` for reuse

**Non-Goals:**
- Changes to the `goodissues_reporter` package (separate repo, separate change)
- Incident dashboard UI (future work)
- Alerting/notification integration for incidents (existing notification system will fire on issue creation as today)
- Changes to the error API or error schema

## Decisions

### D1: Separate `incidents` and `incident_occurrences` tables

Incidents get their own tables rather than sharing with errors or using a unified `trackable_events` table.

**Rationale:** Error and incident data shapes diverge meaningfully — errors have stacktraces, kind/reason from exception types; incidents have severity, source, freeform metadata. A unified table would require nullable columns or JSONB blobs for type-specific data. Separate tables give clean schemas and independent indexes.

**Alternative considered:** Unified `trackable_events` table with a `type` discriminator and JSONB `details` column. Rejected because it trades schema clarity for a minor reduction in dedup code duplication, and the dedup logic is better extracted as shared functions anyway.

### D2: Caller-provided fingerprints with max length (not SHA-256)

Incident fingerprints are caller-provided strings with a maximum length (255 chars), not the 64-char SHA-256 hashes required for errors.

**Rationale:** Incident fingerprints are semantic identifiers chosen by the reporter (e.g., `"system_cpu_threshold_web1"`, `"check_<uuid>"`). Forcing callers to hash these adds complexity with no benefit — the fingerprint is already unique by construction. Max length prevents abuse while allowing readable identifiers.

**Alternative considered:** Require SHA-256 like errors. Rejected because incident fingerprints are meaningful labels, not content hashes.

### D2a: One aggregate incident per account/fingerprint

Incidents are long-lived aggregates keyed by `(account_id, fingerprint)`. When an archived incident fires outside the reopen window, the existing incident record points to a newly-created issue rather than creating another incident row with the same fingerprint.

**Rationale:** The incident record represents the deduplicated stream of occurrences for a semantic fingerprint. Issues represent specific work items opened for that incident over time. Keeping one incident per fingerprint makes list/filter behavior deterministic and allows a simple unique index on `(account_id, fingerprint)`.

### D3: Reopen window in `incident_attrs`

`report_incident/5` accepts an optional `reopen_window_hours` key in `incident_attrs` (default: 24). When a new occurrence arrives and the linked issue is archived within this window, the incident is reopened rather than creating a new one.

**Rationale:** Different sources need different reopen windows — checks and heartbeats have their own `reopen_window_hours` fields, the API might want a default, and the SystemMonitor might want a different value. Keeping it inside `incident_attrs` preserves the fixed `report_incident/5` signature while still allowing callers to override the default.

### D4: Monitoring lifecycle flows through `report_incident/5`

`IncidentLifecycle` and `HeartbeatIncidentLifecycle` are refactored to call `Tracking.report_incident/5` for incident creation/reopening and `Tracking.resolve_incident/2` for recovery. The fingerprint for monitoring-created incidents is derived from the check/heartbeat identity (e.g., `"check_<id>"`, `"heartbeat_<id>"`).

**Rationale:** Single path for all incident lifecycle management. The monitoring modules currently duplicate issue creation/reopen logic that `report_incident/5` handles generically. After refactoring, `SharedIncidentLifecycle.classify_incident/3` logic is absorbed into `report_incident/5`.

**Trade-off:** Monitoring loses some direct control (e.g., setting `check.current_issue_id` inline). The lifecycle modules still handle the linking step after `report_incident/5` returns the incident.

Recovery paths still perform lifecycle-specific cleanup after `resolve_incident/2` succeeds, including clearing `current_issue_id`, updating check/heartbeat status, and preserving any ping/result issue linkage.

### D5: Extract shared dedup into private functions, not a behaviour

The advisory-lock + find-or-create pattern is extracted into private helper functions within the `Tracking` module rather than a separate behaviour or module.

**Rationale:** Both `report_error/5` and `report_incident/5` live in the same module. The shared pattern is: lock on `{account_id, fingerprint}`, look up existing record, branch on create/reopen/add-occurrence. This is 3-4 small private functions, not enough to justify a separate module or behaviour. If a third trackable type is ever added, extraction to a module would make sense.

### D6: Incident issue type is `:incident`

When `report_incident/5` creates a new issue, it uses `type: :incident`. This matches what the monitoring lifecycle already does.

**Rationale:** Consistency with existing monitoring behavior. The `:incident` issue type already exists in the Issue schema enum.

### D7: PATCH updates muting only

`PATCH /api/v1/incidents/:id` updates the `muted` flag only. Status changes remain lifecycle operations handled by `report_incident/5` and `resolve_incident/2`, not generic partial updates.

**Rationale:** Incident status must stay synchronized with linked issue status. Allowing arbitrary status updates via PATCH would require implicit archive/reopen behavior and duplicate lifecycle semantics already handled by dedicated functions.

## Risks / Trade-offs

**[Monitoring refactor scope]** → Refactoring both `IncidentLifecycle` and `HeartbeatIncidentLifecycle` to flow through `report_incident/5` touches critical monitoring paths. Mitigation: Existing test coverage for monitoring lifecycle behavior validates the refactor. The linking step (setting `current_issue_id` on checks/heartbeats) remains in the lifecycle modules.

**[Fingerprint collision across types]** → Errors and incidents use separate tables with separate fingerprint indexes, so there's no collision risk. Advisory lock keys are namespaced by `{account_id, fingerprint}` and the lock key generation uses `phash2` which could theoretically collide between an error fingerprint and incident fingerprint. Mitigation: The lock is scoped to a transaction that only queries one table, so even a hash collision just causes brief serialization, not incorrect behavior.

**[Reopen window complexity]** → The reopen logic requires finding the most recent archived issue for a fingerprint and checking its `archived_at`. This is a query pattern that doesn't exist for errors (errors don't reopen). Mitigation: Index on `(fingerprint, status)` on incidents table makes this lookup efficient.

**[Account-scoped fingerprint uniqueness]** → PostgreSQL cannot enforce uniqueness through an `issue -> project -> account` join. Mitigation: store `account_id` directly on incidents, set it from the validated project/account, and enforce a unique index on `(account_id, fingerprint)`.

## Migration Plan

1. Add `incidents` and `incident_occurrences` tables via migration
2. Add incident context functions and API endpoints
3. Refactor monitoring lifecycle modules to use `report_incident/5`
4. No data migration needed — existing monitoring incidents are issues, not incident records. New incidents created after deployment will use the new tables.
5. Rollback: Drop tables, revert lifecycle modules. No data loss for existing monitoring incidents since they're stored as issues.
