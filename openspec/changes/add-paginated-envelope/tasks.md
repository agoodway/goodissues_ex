## 1. Shared Pagination Schema

- [x] 1.1 Create `FFWeb.Api.V1.Schemas.Pagination` module with `PaginationMeta` schema and `paginated_list/2` helper function
- [x] 1.2 Update `FFWeb.Api.V1.Schemas.Error.ErrorListResponse` to use shared `PaginationMeta` from the new module (remove local `PaginationMeta` definition)
- [x] 1.3 Update `FFWeb.Api.V1.Schemas.Issue.IssueListResponse` to use shared `PaginationMeta` and include `meta` in the response schema
- [x] 1.4 Update `FFWeb.Api.V1.Schemas.Project.ProjectListResponse` to use shared `PaginationMeta` and include `meta` in the response schema

- [x] 1.5 Add pagination parameter validation to controllers — return 400 Bad Request for invalid `page` (0, negative, non-integer) and `per_page` (0, negative, non-integer) values instead of silently falling back to defaults

## 2. Projects Pagination (Backend)

- [x] 2.1 Add `Tracking.list_projects_paginated/2` context function with COUNT + LIMIT/OFFSET pagination, using `extract_pagination/1` (note: `extract_pagination/1` already handles `per_page` clamping to max 100)
- [x] 2.2 Update `ProjectController.index` to call `list_projects_paginated/2`, pass `page`/`per_page` params, and render with pagination assigns
- [x] 2.3 Update `ProjectJSON.index/1` to render `{data, meta}` envelope matching the Errors pattern
- [x] 2.4 Add `page` and `per_page` query parameters to `ProjectController.index` OpenAPI operation spec
- [x] 2.5 Verify existing callers of `Tracking.list_projects/1` (dashboard, etc.) are unaffected by the new paginated variant

## 3. Issues Pagination (Wire Through)

- [x] 3.1 Update `IssueController.index` to pass pagination meta from `list_issues_paginated/2` result to the render call
- [x] 3.2 Update `IssueJSON.index/1` to render `{data, meta}` envelope with `page`, `per_page`, `total`, `total_pages`
- [x] 3.3 Add `page` and `per_page` query parameters to `IssueController.index` OpenAPI operation spec
- [x] 3.4 Pass `page`/`per_page` params from controller through to `list_issues_paginated/2` filters (part of the same controller update as 3.1 — add `:page` and `:per_page` to `build_filters/1`)

## 4. Error Search Pagination (Fix)

- [x] 4.1 Refactor `Tracking.search_errors_by_stacktrace/2` to return `%{errors, page, per_page, total, total_pages}` — the function already uses `LIMIT/OFFSET` but returns a flat list; add a `COUNT` query and return the full pagination map. Ensure that when no filter params are provided, the query still applies pagination (does not return all errors)
- [x] 4.2 Update `ErrorController.search` to use the paginated result map and pass real meta values to render

## 5. Go CLI Update

- [x] 5.1 Add `Meta` struct and update list response types in `cli/internal/client/` to parse `meta` from JSON responses
- [x] 5.2 Update `ListProjects` and `ListIssues` to return `(*ProjectListResponse, error)` and `(*IssueListResponse, error)` respectively, exposing pagination meta to callers (matching the existing `ListErrors` pattern)
- [x] 5.3 Update project list and issue list CLI commands to handle the new return types and display pagination info

## 6. Verification

- [x] 6.1 Run `mix compile --warnings-as-errors` and `mix format --check-formatted`
- [x] 6.2 Run `mix test` and verify no regressions in existing API tests
- [x] 6.3 Verify OpenAPI spec renders correctly at `GET /api/v1/openapi` — all list endpoints show `meta` in response schemas
- [x] 6.4 Build Go CLI (`go build`) and verify it compiles without errors
- [x] 6.5 Verify CLI project list and issue list commands display correct output with paginated response shape (manual smoke test or Go test)
- [x] 6.6 Update existing API controller tests to assert `meta` object is present and contains correct `page`, `per_page`, `total`, `total_pages` values (issue_controller_test, project_controller_test, error_controller_test search endpoint)
