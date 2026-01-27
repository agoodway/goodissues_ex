## 1. Database Schema

- [ ] 1.1 Create migration for `projects` table with fields: id, name, description, account_id, timestamps
- [ ] 1.2 Add index on account_id for efficient queries

## 2. Context and Schema

- [ ] 2.1 Create `FF.Tracking` context module
- [ ] 2.2 Create `FF.Tracking.Project` schema with changeset
- [ ] 2.3 Add context functions: list_projects/1, get_project/2, create_project/2, update_project/2, delete_project/1
- [ ] 2.4 Ensure all queries are scoped to account (multi-tenant isolation)

## 3. OpenAPI Schemas

- [ ] 3.1 Create `FFWeb.Api.V1.Schemas.Project` module with request/response schemas

## 4. API Controller

- [ ] 4.1 Create `FFWeb.Api.V1.ProjectController` with index, show, create, update, delete actions
- [ ] 4.2 Add OpenApiSpex operation specs to controller

## 5. Router Configuration

- [ ] 5.1 Add project routes to read-only API scope (index, show)
- [ ] 5.2 Add project routes to write API scope (create, update, delete)

## 6. Testing

- [ ] 6.1 Write unit tests for `FF.Tracking.Project` schema
- [ ] 6.2 Write context tests for project CRUD operations
- [ ] 6.3 Write controller tests for ProjectController
- [ ] 6.4 Test multi-tenant isolation (cross-account access denied)

## 7. Validation

- [ ] 7.1 Run `mix compile --warnings-as-errors`
- [ ] 7.2 Run `mix test`
- [ ] 7.3 Verify OpenAPI spec renders correctly at `/api/v1/docs`
