# Add Projects Admin UI

## Summary

Add a dashboard UI for managing projects within an account. This includes adding a "Projects" item to the sidebar navigation under the Workspace section. Projects will have a configurable prefix (e.g., "FF") used to generate human-readable issue identifiers like "FF-123".

## Motivation

Currently, projects can only be managed via the REST API. Users need a web interface to:
- Create, view, edit, and delete projects within their account
- Configure a project prefix for human-readable issue identifiers
- See issue counts per project

Issue identifiers like "FF-123" are easier to reference in conversations, commit messages, and documentation compared to UUIDs.

## Scope

### In Scope
1. **Project prefix field**: Add `prefix` field to projects (e.g., "FF", "BUG", "FEAT")
2. **Issue number field**: Add `number` (auto-incrementing integer per project) to issues
3. **Human-readable issue ID**: Combine prefix + number (e.g., "FF-123")
4. **Projects admin UI**: CRUD interface in the dashboard
5. **Sidebar navigation**: Add "Projects" link under "// Workspace" section

### Out of Scope
- Bulk operations on projects
- Project archival/soft delete
- Project templates
- Issue ID in API responses (can be added later)

## Dependencies

- Existing Tracking context with project CRUD functions
- Dashboard layout with sidebar navigation
- Issue schema and LiveView pages

## Risks

- **Migration on existing data**: Need to backfill `number` for existing issues. Mitigated by using a data migration that assigns sequential numbers based on `inserted_at` order.
- **Prefix uniqueness**: Prefix must be unique within an account to avoid ID collisions. Enforced via database constraint.
- **Concurrent issue creation**: Race condition when incrementing issue numbers. Mitigated by using database-level `SELECT ... FOR UPDATE` or a sequence per project.

## Alternatives Considered

1. **Global sequence instead of per-project**: Would give IDs like "FF-1", "FF-2" across all projects. Rejected because per-project sequences (FF-1, BUG-1) are more intuitive.

2. **Auto-generate prefix from project name**: E.g., "FruitFly" → "FF". Rejected because users should have control over the prefix, and auto-generation could produce awkward results.

3. **Store computed ID in database**: Store "FF-123" as a string field. Rejected because it's denormalized and makes prefix changes harder.
