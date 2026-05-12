# Inspector Reconcile — add-incident-api

**Reconciled:** 2026-05-12
**Verdict:** Fully aligned (pre-implementation)

## Summary

No implementation has started for this change. All 26 tasks across 7 sections remain at "not started." The specs describe future work and the codebase has not diverged from the pre-change baseline. No patches were needed.

**Counts:** Auto-patched: 0 · User-guided: 0 · Skipped: 0 · Already aligned: 26

## Implementation Status

| Task | Status | Evidence |
|------|--------|----------|
| 1.1 Create incidents migration | Not started | No migration with "incident" in `priv/repo/migrations/` |
| 1.2 Create incident_occurrences migration | Not started | No migration with "incident" in `priv/repo/migrations/` |
| 2.1 Create Incident schema | Not started | No `lib/good_issues/tracking/incident.ex` |
| 2.2 Create IncidentOccurrence schema | Not started | No `lib/good_issues/tracking/incident_occurrence.ex` |
| 3.1 Extract shared dedup helpers | Not started | `report_error/5` at `tracking.ex:950` unchanged |
| 3.2 Refactor report_error/5 | Not started | No extracted dedup helpers exist |
| 3.3 Implement report_incident/5 | Not started | No `report_incident` in codebase |
| 3.4 Implement resolve_incident/2 | Not started | No `resolve_incident` in codebase |
| 3.5 Implement get_incident/3, get_incident_by_fingerprint/2 | Not started | No `get_incident` in codebase |
| 3.6 Implement list_incidents_paginated/2 | Not started | No `list_incidents` in codebase |
| 3.7 Implement get_incident_with_occurrences/3 | Not started | No function in codebase |
| 3.8 Implement update_incident/2 | Not started | No `update_incident` in codebase |
| 4.1 Create Incident OpenAPI schema | Not started | No `schemas/incident.ex` in web layer |
| 4.2 Create IncidentController | Not started | No `incident_controller.ex` |
| 4.3 Create IncidentJSON view | Not started | No `incident_json.ex` |
| 4.4 Add incident routes | Not started | No "incident" in `router.ex` |
| 4.5 Add incidents:read/write scopes | Not started | `api_key.ex:13-20` has no incident scopes |
| 5.1 Refactor IncidentLifecycle | Not started | `incident_lifecycle.ex` still calls `Tracking.create_issue` directly |
| 5.2 Refactor HeartbeatIncidentLifecycle | Not started | `heartbeat_incident_lifecycle.ex` still calls `Tracking.create_issue` directly |
| 5.3 Evaluate SharedIncidentLifecycle removal | Not started | `shared_incident_lifecycle.ex` still in use |
| 6.1 Schema changeset tests | Not started | No schemas to test |
| 6.2 report_incident/5 tests | Not started | No function to test |
| 6.3 resolve_incident/2 tests | Not started | No function to test |
| 6.4 list/get/update tests | Not started | No functions to test |
| 6.5 Controller tests | Not started | No controller to test |
| 6.6 Verify monitoring tests pass | Not started | Tests exist for current behavior; refactor hasn't happened |
| 6.7 Verify error tracking tests pass | Not started | Dedup extraction hasn't happened |
| 6.8 Advanced context tests | Not started | No functions to test |
| 6.9 Advanced controller tests | Not started | No controller to test |
| 7.1 Regenerate openapi.json | Not started | No "incident" in `openapi.json` |

## Patches Applied

### Auto-patched
None.

### User-guided
None.

### Skipped
None.

## Remaining Drift

None. The specs describe future work and the codebase is at the expected pre-implementation baseline.

## What's Aligned

- All task checkboxes correctly unchecked — no implementation exists
- Existing monitoring lifecycle modules (`IncidentLifecycle`, `HeartbeatIncidentLifecycle`, `SharedIncidentLifecycle`) are in the expected pre-refactor state: they create issues directly via `Tracking.create_issue`
- Issue schema already includes `:incident` in `@type_values` enum (design decision D6 is pre-satisfied)
- `report_error/5` at `tracking.ex:950` has the dedup pattern ready for extraction (task 3.1)
- API key scopes in `api_key.ex` follow the pattern that incident scopes will extend
- Router and controller directory structure match the expected layout for new incident endpoints
