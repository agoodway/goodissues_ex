## MODIFIED Requirements

### Requirement: Error API Endpoints

#### Scenario: Search by stacktrace (MODIFIED)
- Given errors with various stacktraces
- When GET /api/v1/errors/search with module=MyApp.Worker
- Then errors with matching stacktrace lines are returned
- And results SHALL be paginated with accurate `meta` containing `page`, `per_page`, `total`, and `total_pages`
- And the pagination SHALL use DB-level COUNT + LIMIT/OFFSET (not in-memory)

#### Scenario: List errors with filters (MODIFIED)
- Given multiple errors exist
- When GET /api/v1/errors with status=unresolved
- Then only unresolved errors are returned
- And the response SHALL include `meta` referencing the shared `PaginationMeta` schema
