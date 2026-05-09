## ADDED Requirements

### Requirement: All list endpoints return paginated envelope
Every REST API list endpoint SHALL return a JSON response with `data` (array of resources) and `meta` (pagination metadata) at the top level.

#### Scenario: Standard paginated list response
- **WHEN** a client sends `GET /api/v1/projects`
- **THEN** the response body SHALL have the shape `{"data": [...], "meta": {"page": 1, "per_page": 20, "total": N, "total_pages": M}}`

#### Scenario: Response with no results
- **WHEN** a client sends `GET /api/v1/issues?status=archived` and no matching issues exist
- **THEN** the response body SHALL be `{"data": [], "meta": {"page": 1, "per_page": 20, "total": 0, "total_pages": 1}}`

### Requirement: All list endpoints accept page and per_page query parameters
Every REST API list endpoint SHALL accept `page` (integer, minimum 1) and `per_page` (integer, minimum 1, maximum 100) query parameters.

#### Scenario: Default pagination
- **WHEN** a client sends `GET /api/v1/projects` without page or per_page
- **THEN** the response SHALL default to page 1 with 20 results per page

#### Scenario: Custom page size
- **WHEN** a client sends `GET /api/v1/projects?per_page=50&page=2`
- **THEN** the response SHALL return up to 50 results starting from offset 50, with meta reflecting page 2

#### Scenario: Per_page exceeds maximum
- **WHEN** a client sends `GET /api/v1/issues?per_page=200`
- **THEN** the system SHALL clamp per_page to 100

#### Scenario: Invalid page parameter
- **WHEN** a client sends `GET /api/v1/projects?page=0` or `page=abc` or `page=-1`
- **THEN** the system SHALL return 400 Bad Request with an error message indicating the page parameter is invalid

#### Scenario: Invalid per_page parameter
- **WHEN** a client sends `GET /api/v1/projects?per_page=0` or `per_page=abc` or `per_page=-1`
- **THEN** the system SHALL return 400 Bad Request with an error message indicating the per_page parameter is invalid

### Requirement: Shared PaginationMeta OpenAPI schema
A single shared `PaginationMeta` schema module SHALL be used by all list response OpenAPI schemas.

#### Scenario: OpenAPI spec consistency
- **WHEN** the OpenAPI spec is generated at `GET /api/v1/openapi`
- **THEN** all list response schemas SHALL reference the same `PaginationMeta` schema definition

### Requirement: Projects endpoint supports real pagination
`GET /api/v1/projects` SHALL perform DB-level pagination using COUNT + LIMIT/OFFSET queries.

#### Scenario: Paginated project list
- **WHEN** an account has 30 projects and a client sends `GET /api/v1/projects?per_page=10&page=2`
- **THEN** the response SHALL contain 10 projects (items 11-20) with `meta.total` equal to 30 and `meta.total_pages` equal to 3

### Requirement: Issues endpoint exposes existing pagination metadata
`GET /api/v1/issues` SHALL include pagination metadata in the response. The backend already paginates; the controller and JSON view SHALL pass through the `meta` object.

#### Scenario: Issues list includes meta
- **WHEN** a client sends `GET /api/v1/issues?page=2&per_page=10`
- **THEN** the response SHALL include `meta` with accurate `page`, `per_page`, `total`, and `total_pages` values

### Requirement: Error search uses DB-level pagination
`GET /api/v1/errors/search` SHALL use DB-level COUNT + LIMIT/OFFSET pagination instead of loading all results into memory.

#### Scenario: Paginated error search
- **WHEN** a client sends `GET /api/v1/errors/search?module=MyApp.Repo&page=1&per_page=10`
- **THEN** the response SHALL contain at most 10 errors with accurate `meta.total` reflecting the full count of matching errors in the database

#### Scenario: Error search with no filters
- **WHEN** a client sends `GET /api/v1/errors/search` with no search filters
- **THEN** the response SHALL return a paginated empty result set, not all errors

### Requirement: Go CLI handles paginated list responses
The Go CLI's API client SHALL parse the `meta` field from all list endpoint responses.

#### Scenario: CLI parses project list with meta
- **WHEN** the CLI calls `GET /api/v1/projects`
- **THEN** the client SHALL deserialize both the `data` array and the `meta` pagination object without error
