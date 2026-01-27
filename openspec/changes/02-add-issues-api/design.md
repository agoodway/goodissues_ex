## Context

This change adds issue tracking to FruitFly, building on the projects capability from 01-add-projects-api. Issues are the core entity for tracking bugs and feature requests.

## Goals / Non-Goals

### Goals
- Provide a complete CRUD API for issues
- Support filtering by project, status, and type
- Track submitter via user reference and optional email
- Auto-manage archived_at timestamp based on status
- Generate accurate OpenAPI documentation

### Non-Goals
- Comments on issues
- Attachments/file uploads
- Issue assignment to users
- Notifications
- Status transition validation (any status can change to any other)
- Pagination (initial implementation)

## Decisions

### Submitter Tracking
**Decision**: Store both `submitter_id` (foreign key to users) and optional `submitter_email` (string).
**Rationale**:
- `submitter_id` provides database integrity and links to existing user data
- `submitter_email` allows tracking external reporters (e.g., from a public feedback form)
- The email is optional and can differ from the authenticated user's email

### Status Transitions
**Decision**: No state machine enforcement; any status can transition to any other status.
**Rationale**: Keep initial implementation simple. Status transitions can be validated later if workflows require it.

### Archived Timestamp Management
**Decision**: `archived_at` is automatically set/cleared when status changes to/from `archived`.
**Rationale**: Provides queryable timestamp for "when was this closed" without requiring separate API calls.

### Hard Delete
**Decision**: Use hard delete for issues.
**Rationale**: Simpler initial implementation. Soft delete can be added later if audit requirements emerge.

### Project Deletion Protection
**Decision**: Issues use `ON DELETE RESTRICT` for project_id.
**Rationale**: Prevents accidental data loss. Users must delete or move issues before deleting a project.

## Data Model

```
projects (from 01-add-projects-api)
    |
    +-- issues --> users (submitter_id)
```

### Issues Table
```sql
CREATE TABLE issues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  type VARCHAR(20) NOT NULL,  -- 'bug' | 'feature_request'
  status VARCHAR(20) NOT NULL DEFAULT 'new',  -- 'new' | 'in_progress' | 'archived'
  priority VARCHAR(20) NOT NULL DEFAULT 'medium',  -- 'low' | 'medium' | 'high' | 'critical'
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE RESTRICT,
  submitter_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  submitter_email VARCHAR(255),
  resolved_at TIMESTAMP,
  archived_at TIMESTAMP,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX issues_project_id_index ON issues(project_id);
CREATE INDEX issues_status_index ON issues(status);
CREATE INDEX issues_type_index ON issues(type);
```

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /api/v1/issues | Read | List all issues (filterable) |
| GET | /api/v1/issues/:id | Read | Get issue by ID |
| POST | /api/v1/issues | Write | Create new issue |
| PATCH | /api/v1/issues/:id | Write | Update issue |
| DELETE | /api/v1/issues/:id | Write | Delete issue |

### Query Parameters for List
| Parameter | Type | Description |
|-----------|------|-------------|
| project_id | UUID | Filter by project |
| status | string | Filter by status (new, in_progress, archived) |
| type | string | Filter by type (bug, feature_request) |

## Risks / Trade-offs

### Risk: Orphaned Issues on Project Deletion
**Mitigation**: `ON DELETE RESTRICT` prevents deletion of projects with issues. API returns appropriate error.

### Trade-off: No Pagination
List endpoint returns all matching results. Acceptable for initial implementation but should be added when issue counts grow.

### Trade-off: No Search
Text search on title/description not included. Can be added later with PostgreSQL full-text search.

## Open Questions

None.
