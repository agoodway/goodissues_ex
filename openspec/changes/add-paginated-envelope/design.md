## Context

The GoodIssues REST API has three list endpoints with inconsistent response shapes:

| Endpoint | Backend Pagination | Response Meta | OpenAPI Params |
|---|---|---|---|
| `GET /projects` | None (returns all) | None | None |
| `GET /issues` | Yes (`list_issues_paginated`) | Discarded by controller | None |
| `GET /errors` | Yes (`list_errors_paginated`) | Full `{data, meta}` | `page`, `per_page` |
| `GET /errors/search` | Fake (loads all, shims meta) | Shim `{data, meta}` | `page`, `per_page` |

The Errors endpoint is the reference implementation. The goal is to bring all endpoints to that standard.

The Go CLI (`cli/`) consumes all these endpoints. No backwards compatibility constraints — the owner has confirmed additive `meta` field addition is safe and the CLI should be updated.

## Goals / Non-Goals

**Goals:**
- Every list endpoint returns `{data: [...], meta: {page, per_page, total, total_pages}}`
- Every list endpoint accepts `page` and `per_page` query parameters
- Shared `PaginationMeta` OpenAPI schema used by all list responses
- Real DB-level pagination for projects and error search
- Go CLI handles paginated responses for all resources

**Non-Goals:**
- Cursor-based pagination (offset-based is sufficient for current scale)
- Infinite scroll / streaming responses
- Changing the `{data: {...}}` wrapper on single-resource responses
- Adding pagination to write endpoints (create, update, delete)

## Decisions

### 1. Shared pagination schema module

**Decision**: Create `GIWeb.Api.V1.Schemas.Pagination` with `PaginationMeta` and a `paginated_list/2` helper that generates list response schemas.

**Rationale**: The `PaginationMeta` schema currently lives inside `GIWeb.Api.V1.Schemas.Error`. Duplicating it per-resource creates drift risk. A shared module with a helper function keeps all list response schemas DRY:

```elixir
# Usage in each resource's schema module:
defmodule ProjectListResponse do
  OpenApiSpex.schema(Pagination.paginated_list("Project", ProjectResponse))
end
```

**Alternative considered**: Leave `PaginationMeta` in Error schemas and reference it from other modules. Rejected because it creates a confusing dependency (why do Projects reference Error schemas?).

### 2. Pagination defaults and limits

**Decision**: Use the same defaults already established by the Errors endpoint — `page` defaults to `1`, `per_page` defaults to `20`, max `per_page` is `100`. These are already defined in `Tracking.extract_pagination/1`.

**Rationale**: Consistency. The infrastructure already exists. Projects will use the same `extract_pagination/1` helper.

### 3. Projects pagination — new context function

**Decision**: Add `Tracking.list_projects_paginated/2` alongside the existing `list_projects/1`. Keep `list_projects/1` for internal use (dashboard, etc.) but have the API controller call the paginated variant.

**Rationale**: The dashboard's project list doesn't need pagination overhead. Adding a separate function avoids changing internal callers.

### 4. Error search — real DB-level pagination

**Decision**: Refactor `Tracking.search_errors_by_stacktrace/2` to use the same `extract_pagination/1` + count/offset pattern as `list_errors_paginated/2`, returning `%{errors, page, per_page, total, total_pages}`.

**Rationale**: The current implementation already uses DB-level `LIMIT/OFFSET` in the query, but returns a flat list — no `COUNT` query is run, and the controller hardcodes `page: 1, per_page: 20, total_pages: 1` in the response meta. Adding a count query and returning the full pagination map (matching the `list_errors_paginated/2` pattern) makes the meta accurate.

### 5. Go CLI response handling

**Decision**: Update the CLI's API client response structs to include a `Meta` field for paginated list responses. Parse `meta` from JSON when present.

**Rationale**: The CLI currently reads `data` arrays directly. With `meta` added, the client can display pagination info and eventually support `--page` flags.

## Risks / Trade-offs

- **[Risk] Existing API consumers break** → Mitigated: owner confirmed no backwards compat concerns. The `data` key is unchanged; `meta` is purely additive.
- **[Risk] Project list performance with pagination overhead** → Low risk: pagination adds one COUNT query. Projects are low-cardinality (tens per account). The overhead is negligible.
- **[Risk] Error search result count changes** → Currently returns all results. After pagination, clients get 20 per page by default. CLI needs to handle this or pass `per_page=100` for larger result sets.
