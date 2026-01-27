## Prerequisites
- [ ] 0.1 Ensure 01-add-projects-api is implemented and merged

## 1. Database Schema

- [ ] 1.1 Create migration for `issues` table with fields: id, title, description, type, status, priority, project_id, submitter_id, submitter_email, resolved_at, archived_at, timestamps
- [ ] 1.2 Add foreign key constraint to projects (ON DELETE RESTRICT)
- [ ] 1.3 Add foreign key constraint to users for submitter_id (ON DELETE RESTRICT)
- [ ] 1.4 Add indexes for project_id, status, type

## 2. Schema

- [ ] 2.1 Create `FF.Tracking.Issue` schema with Ecto.Enum types for type, status, priority
- [ ] 2.2 Implement changeset with validation for required fields
- [ ] 2.3 Add logic to auto-set archived_at when status changes to/from archived

## 3. Context Functions

- [ ] 3.1 Add `list_issues/2` with account scoping and optional filters (project_id, status, type)
- [ ] 3.2 Add `get_issue/2` with account scoping
- [ ] 3.3 Add `create_issue/2` that sets submitter_id from current user
- [ ] 3.4 Add `update_issue/2` with archived_at timestamp management
- [ ] 3.5 Add `delete_issue/1`

## 4. OpenAPI Schemas

- [ ] 4.1 Create `FFWeb.Api.V1.Schemas.Issue` module with request/response schemas
- [ ] 4.2 Define enum schemas for IssueType, IssueStatus, IssuePriority
- [ ] 4.3 Create IssueFilterParams schema for query parameters

## 5. API Controller

- [ ] 5.1 Create `FFWeb.Api.V1.IssueController` with index, show, create, update, delete actions
- [ ] 5.2 Add OpenApiSpex operation specs to controller
- [ ] 5.3 Implement filtering for index action

## 6. Router Configuration

- [ ] 6.1 Add issue routes to read-only API scope (index, show)
- [ ] 6.2 Add issue routes to write API scope (create, update, delete)

## 7. Testing

- [ ] 7.1 Write unit tests for `FF.Tracking.Issue` schema
- [ ] 7.2 Write context tests for issue CRUD operations
- [ ] 7.3 Write context tests for issue filtering
- [ ] 7.4 Write controller tests for IssueController
- [ ] 7.5 Test multi-tenant isolation (cross-account access denied)
- [ ] 7.6 Test archived_at timestamp management

## 8. Validation

- [ ] 8.1 Run `mix compile --warnings-as-errors`
- [ ] 8.2 Run `mix test`
- [ ] 8.3 Verify OpenAPI spec renders correctly at `/api/v1/docs`
- [ ] 8.4 Test API endpoints manually via Swagger UI
