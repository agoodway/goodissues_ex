## Why

The system lacks a first-class incident reporting API. Today, the SystemMonitor in goodissues_reporter shoehorns incidents (resource threshold breaches) through the error API, which expects stacktrace-centric data and enforces a 64-character SHA-256 fingerprint. Meanwhile, the monitoring subsystem creates incident issues through its own lifecycle modules that bypass the Tracking context's dedup machinery. Adding a dedicated incident API with caller-provided fingerprinting and dedup gives external reporters and internal monitoring a single, clean path for incident lifecycle management.

## What Changes

- Add an `incidents` table with account-scoped fingerprint deduplication, caller-provided fingerprints (max-length string, not SHA-256), severity levels, source tracking, and freeform metadata
- Add an `incident_occurrences` table (separate from error occurrences) for recording each firing of an incident
- Add `Tracking.report_incident/5` with advisory-lock dedup and reopen-window semantics, mirroring the pattern from `report_error/5`
- Add `Tracking.resolve_incident/2` for programmatic resolution (archives linked issue)
- Add REST API endpoints: `POST/GET/PATCH /api/v1/incidents`, `GET /api/v1/incidents/:id`; PATCH updates incident muting only
- Refactor `IncidentLifecycle` and `HeartbeatIncidentLifecycle` to flow through `report_incident/5` and `resolve_incident/2` instead of directly creating/updating issues
- Extract shared dedup mechanics (advisory lock + find-or-create) from `report_error/5` for reuse

## Capabilities

### New Capabilities
- `incident-api`: REST API for reporting, listing, and managing incidents with fingerprint dedup and occurrence tracking

### Modified Capabilities
- `incident-lifecycle`: Monitoring incident lifecycle refactored to flow through `report_incident/5` and `resolve_incident/2` instead of direct issue manipulation
- `error-tracking`: Extract shared dedup pattern from `report_error/5` for reuse by incident reporting

## Impact

- **Database**: Two new tables (`incidents`, `incident_occurrences`), new migration
- **Tracking context**: New incident functions, refactored dedup extraction, modified `report_error/5` internals
- **Monitoring context**: `IncidentLifecycle`, `HeartbeatIncidentLifecycle`, and `SharedIncidentLifecycle` refactored to use `report_incident/5`
- **Web layer**: New `IncidentController`, JSON view, OpenAPI schemas, route entries
- **API scopes**: New `incidents:read` and `incidents:write` scopes
- **Reporter (external)**: `SystemMonitor` switches from `create_error` to `create_incident` (separate change in goodissues_reporter)
