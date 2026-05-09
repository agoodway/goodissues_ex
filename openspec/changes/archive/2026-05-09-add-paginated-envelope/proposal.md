## Why

The REST API returns list responses in inconsistent shapes. Errors use a paginated envelope (`{data, meta}`), issues silently discard pagination metadata the backend already computes, and projects have no pagination at all. This inconsistency makes the API harder to consume — the Go CLI and any future clients must handle each endpoint differently. Standardizing on a single paginated envelope makes all list endpoints predictable and enables clients to implement generic pagination logic.

## What Changes

- Extract `PaginationMeta` into a shared OpenAPI schema module used by all list endpoints
- Add real DB-level pagination to `GET /projects` (currently returns unpaginated list)
- Wire existing pagination metadata through to `GET /issues` response (backend already paginates, but meta is discarded at the controller/JSON layer)
- Add `page` and `per_page` query parameters to Issues and Projects OpenAPI specs
- Replace in-memory load-all in `GET /errors/search` with real DB-level paginated query
- Update all `*ListResponse` OpenAPI schemas to include the shared `meta` object
- Update all `*JSON.index/1` views to render the `{data, meta}` envelope
- Update Go CLI client to handle the new envelope shape on projects and issues responses

## Capabilities

### New Capabilities
- `paginated-envelope`: Shared pagination response envelope for all REST API list endpoints, including the meta schema, query parameter conventions, and per-endpoint pagination behavior

### Modified Capabilities
- `error-tracking`: Error search endpoint returns real DB-level pagination metadata instead of hardcoded values; error list response schema updated to use shared `PaginationMeta`

## Impact

- **API controllers**: `ProjectController.index`, `IssueController.index` gain pagination params and meta rendering
- **Context functions**: `Tracking.list_projects/1` replaced by `list_projects_paginated/2`; `Tracking.search_errors_by_stacktrace/2` refactored for DB-level pagination
- **JSON views**: `ProjectJSON.index/1` and `IssueJSON.index/1` updated to render `{data, meta}` envelope
- **OpenAPI schemas**: All `*ListResponse` schemas updated; new shared `Pagination` schema module
- **Go CLI**: `internal/client/` response parsing updated for projects and issues list endpoints
- **Existing clients**: Additive change — `data` key unchanged, `meta` key added. No backwards compatibility concerns per stakeholder decision.

**Dependency note**: The `add-uptime-checks` change introduces two new list endpoints (`GET checks`, `GET check results`) that use a paginated envelope. Once this change lands, `add-uptime-checks` should reference the shared `PaginationMeta` schema rather than defining its own local pagination structure.
