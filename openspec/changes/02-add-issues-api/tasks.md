## Prerequisites
- [x] 0.1 Ensure 01-add-projects-api is implemented and merged

## 1. Database Schema

- [x] 1.1 Create migration for `issues` table with fields: id, title, description, type, status, priority, project_id, submitter_id, submitter_email, resolved_at, archived_at, timestamps
- [x] 1.2 Add foreign key constraint to projects (ON DELETE RESTRICT)
- [x] 1.3 Add foreign key constraint to users for submitter_id (ON DELETE RESTRICT)
- [x] 1.4 Add indexes for project_id, status, type

## 2. Schema

- [x] 2.1 Create `FF.Tracking.Issue` schema with Ecto.Enum types for type, status, priority
- [x] 2.2 Implement changeset with validation for required fields
- [x] 2.3 Add logic to auto-set archived_at when status changes to/from archived

## 3. Context Functions

- [x] 3.1 Add `list_issues/2` with account scoping and optional filters (project_id, status, type)
- [x] 3.2 Add `get_issue/2` with account scoping
- [x] 3.3 Add `create_issue/2` that sets submitter_id from current user
- [x] 3.4 Add `update_issue/2` with archived_at timestamp management
- [x] 3.5 Add `delete_issue/1`

## 4. OpenAPI Schemas

- [x] 4.1 Create `FFWeb.Api.V1.Schemas.Issue` module with request/response schemas
- [x] 4.2 Define enum schemas for IssueType, IssueStatus, IssuePriority
- [x] 4.3 Create IssueFilterParams schema for query parameters

## 5. API Controller

- [x] 5.1 Create `FFWeb.Api.V1.IssueController` with index, show, create, update, delete actions
- [x] 5.2 Add OpenApiSpex operation specs to controller
- [x] 5.3 Implement filtering for index action

## 6. Router Configuration

- [x] 6.1 Add issue routes to read-only API scope (index, show)
- [x] 6.2 Add issue routes to write API scope (create, update, delete)

## 7. Testing

- [x] 7.1 Write unit tests for `FF.Tracking.Issue` schema
- [x] 7.2 Write context tests for issue CRUD operations
- [x] 7.3 Write context tests for issue filtering
- [x] 7.4 Write controller tests for IssueController
- [x] 7.5 Test multi-tenant isolation (cross-account access denied)
- [x] 7.6 Test archived_at timestamp management

## 8. Validation

- [x] 8.1 Run `mix compile --warnings-as-errors`
- [x] 8.2 Run `mix test`
- [x] 8.3 Verify OpenAPI spec renders correctly at `/api/v1/docs`
- [x] 8.4 Test API endpoints manually via Swagger UI
