## Context

This change adds project management to FruitFly as the foundation for issue tracking. The system already has:
- Multi-tenant accounts with users and API key authentication
- OpenAPI documentation via `open_api_spex`
- Established patterns for contexts, schemas, and controllers

## Goals / Non-Goals

### Goals
- Provide a complete CRUD API for projects
- Maintain multi-tenant isolation (account-scoped data)
- Follow existing codebase conventions
- Generate accurate OpenAPI documentation
- Establish the `FF.Tracking` context for future issue tracking

### Non-Goals
- Project archiving/soft delete
- Project settings or configuration
- Project members (beyond account-level access)

## Decisions

### Context Naming: `FF.Tracking`
**Decision**: Use `FF.Tracking` as the context module name.
**Rationale**: "Tracking" is broad enough to encompass projects, issues, and future related features (milestones, labels, etc.) without being too generic.

### Hard Delete
**Decision**: Use hard delete for projects.
**Rationale**: Simpler initial implementation. Soft delete can be added later if audit requirements emerge. Foreign key constraints will prevent deletion of projects with issues (added in 02-add-issues-api).

## Data Model

```
accounts (existing)
    |
    +-- projects
```

### Projects Table
```sql
CREATE TABLE projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX projects_account_id_index ON projects(account_id);
```

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /api/v1/projects | Read | List all projects for account |
| GET | /api/v1/projects/:id | Read | Get project by ID |
| POST | /api/v1/projects | Write | Create new project |
| PATCH | /api/v1/projects/:id | Write | Update project |
| DELETE | /api/v1/projects/:id | Write | Delete project |

## Risks / Trade-offs

### Trade-off: No Pagination Initially
The list endpoint returns all results without pagination. Acceptable for initial implementation but should be added when accounts have many projects.

## Open Questions

None.
