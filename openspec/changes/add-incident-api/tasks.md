## 1. Database

- [x] 1.1 Create migration for `incidents` table (id, account_id FK, fingerprint, title, severity, source, status, muted, last_occurrence_at, metadata, issue_id FK, timestamps) with unique index on `(account_id, fingerprint)` and unique index on issue_id
- [x] 1.2 Create migration for `incident_occurrences` table (id, incident_id FK, context JSONB, inserted_at) with index on incident_id

## 2. Schemas

- [x] 2.1 Create `GI.Tracking.Incident` Ecto schema with create_changeset and update_changeset, account association, severity enum (info/warning/critical), status enum (resolved/unresolved), fingerprint max 255 chars, virtual occurrence_count field
- [x] 2.2 Create `GI.Tracking.IncidentOccurrence` Ecto schema with create_changeset, context map validation (max 50 keys), immutable (no updated_at)

## 3. Core Context Functions

- [x] 3.1 Extract shared dedup helpers from `Tracking.report_error/5` into private functions, reusing the existing `fingerprint_lock_key/2` and adding `dedup_with_lock/5` (advisory lock + find-by-fingerprint + branch)
- [x] 3.2 Refactor `report_error/5` to use the extracted dedup helpers (verify no behavior change)
- [x] 3.3 Implement `Tracking.report_incident/5` using shared dedup helpers with `reopen_window_hours` read from `incident_attrs` (default 24h), returns `{:ok, incident, :created | :reopened | :occurrence_added}`
- [x] 3.4 Implement `Tracking.resolve_incident/2` — marks incident resolved, archives linked issue
- [x] 3.5 Implement `Tracking.get_incident/3`, `Tracking.get_incident_by_fingerprint/2`
- [x] 3.6 Implement `Tracking.list_incidents_paginated/2` with status, severity, muted, and source filters
- [x] 3.7 Implement `Tracking.get_incident_with_occurrences/3` with paginated occurrences
- [x] 3.8 Implement `Tracking.update_incident/2` for muted updates only

## 4. API Layer

- [x] 4.1 Create `GIWeb.Api.V1.Schemas.Incident` OpenAPI schema module (request/response schemas)
- [x] 4.2 Create `GIWeb.Api.V1.IncidentController` with create, index, show, update actions
- [x] 4.3 Create `GIWeb.Api.V1.IncidentJSON` view module
- [x] 4.4 Add routes to router: `POST/GET /api/v1/incidents`, `GET/PATCH /api/v1/incidents/:id`
- [x] 4.5 Add `incidents:read` and `incidents:write` API key scopes

## 5. Monitoring Lifecycle Refactor

- [x] 5.1 Refactor `GI.Monitoring.IncidentLifecycle` to use `Tracking.report_incident/5` for create/reopen with fingerprint `"check_<id>"` and `Tracking.resolve_incident/2` for recovery while preserving check status cleanup, `current_issue_id` clearing, and result issue linkage
- [x] 5.2 Refactor `GI.Monitoring.HeartbeatIncidentLifecycle` to use `Tracking.report_incident/5` with fingerprint `"heartbeat_<id>"` and `Tracking.resolve_incident/2` for recovery while preserving heartbeat status cleanup, `current_issue_id` clearing, and ping issue linkage
- [x] 5.3 Evaluate whether `SharedIncidentLifecycle` can be removed (its classify logic should be absorbed into `report_incident/5`)

## 6. Tests

- [x] 6.1 Unit tests for `Incident` and `IncidentOccurrence` schema changesets
- [x] 6.2 Context tests for `report_incident/5` — new incident, add occurrence, reopen within window, create new outside window, project not found
- [x] 6.3 Context tests for `resolve_incident/2` — resolve open, resolve already-resolved
- [x] 6.4 Context tests for list/get/update incident functions, including that update only permits muting changes
- [x] 6.5 Controller tests for all incident API endpoints (create, index, show, update, auth, not-found)
- [x] 6.6 Verify existing monitoring lifecycle tests still pass after refactor
- [x] 6.7 Verify existing error tracking tests still pass after dedup extraction
- [x] 6.8 Context tests for incident account isolation, advisory-lock concurrency, invalid severity/status/fingerprint validation, and pagination bounds
- [x] 6.9 Controller tests for validation errors, malformed UUID/not-found responses, forbidden scopes, write-scope denial, and project/account isolation

## 7. OpenAPI Spec

- [x] 7.1 Regenerate `openapi.json` with new incident endpoints
