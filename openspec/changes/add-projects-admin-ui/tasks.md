# Tasks: Add Projects Admin UI

## Phase 1: Schema Changes

1. [x] **Add prefix and issue_counter to projects**
   - Create migration adding `prefix` (string, max 10) and `issue_counter` (integer, default 1) columns
   - Update `FF.Tracking.Project` schema with new fields
   - Add validation: prefix required, uppercase alphanumeric, 1-10 chars
   - Add unique constraint on (account_id, prefix)
   - Validation: `mix test test/app/tracking_test.exs`

2. [x] **Add number field to issues**
   - Create migration adding `number` (integer) column to issues
   - Add unique constraint on (project_id, number)
   - Update `FF.Tracking.Issue` schema with number field
   - Validation: `mix test test/app/tracking_test.exs`

3. [x] **Backfill existing data**
   - Create data migration to:
     - Generate prefixes from existing project names (first 3 letters, uppercase)
     - Assign sequential numbers to existing issues (ordered by inserted_at)
     - Update issue_counter on each project to max(number) + 1
   - Validation: Run migration on dev database, verify data integrity

4. [x] **Add NOT NULL constraints**
   - Create migration to add NOT NULL to prefix and number after backfill
   - Validation: Migration succeeds, `mix ecto.migrate`

## Phase 2: Context Updates

5. [x] **Update create_project to require prefix**
   - Modify `Tracking.create_project/2` to accept and validate prefix
   - Add helper function to generate suggested prefix from name
   - Validation: `mix test test/app/tracking_test.exs` - add test for prefix validation

6. [x] **Update create_issue to assign number atomically**
   - Wrap issue creation in transaction with `FOR UPDATE` lock on project
   - Assign number from project.issue_counter
   - Increment issue_counter
   - Validation: Add test for concurrent issue creation, verify unique numbers

7. [x] **Add issue identifier helper**
   - Add `issue_key/1` function that returns "{prefix}-{number}"
   - Add `Project` preload to issue queries where identifier is needed
   - Validation: Unit test for `issue_key/1`

## Phase 3: Projects Admin UI

8. [x] **Add projects routes**
   - Add routes under dashboard scope:
     - `live "/projects", ProjectLive.Index, :index`
     - `live "/projects/new", ProjectLive.New, :new`
     - `live "/projects/:id", ProjectLive.Show, :show`
   - Validation: Routes compile, `mix phx.routes`

9. [x] **Add Projects link to sidebar**
   - Edit `layouts.ex` to add "Projects" link after "Issues" in sidebar
   - Add `:projects` to `active_nav` options
   - Validation: Visual inspection, link navigates correctly

10. [x] **Create ProjectLive.Index**
    - List all projects for current account
    - Display columns: NAME, PREFIX, ISSUES, CREATED
    - Show "New Project" button if user has write access
    - Empty state with terminal aesthetic
    - Validation: Visual inspection, pagination if needed

11. [x] **Create ProjectLive.New**
    - Form with name, prefix, description fields
    - Auto-suggest prefix from name (client-side)
    - Validation errors display inline
    - Redirect to index on success
    - Validation: Create project, verify in database

12. [x] **Create ProjectLive.Show**
    - Display/edit project details
    - Show recent issues from project (read-only list)
    - Read-only mode for users without write access
    - Delete button with confirmation
    - Validation: Edit project, delete project, verify permissions

## Phase 4: Issue Identifier Display

13. [x] **Update issue list to show identifier**
    - Modify IssueLive.Index to display "FF-123" style identifier
    - Preload project.prefix for each issue
    - Validation: Visual inspection of issues list

14. [x] **Update issue detail to show identifier**
    - Modify IssueLive.Show to display identifier in header
    - Validation: Visual inspection of issue detail page

## Phase 5: API Updates (Optional)

15. [x] **Add key field to issue API responses**
    - Update IssueController to include `key` field in JSON response
    - Update OpenAPI spec with new field
    - Validation: `mix test test/app_web/controllers/issue_controller_test.exs`

---

## Dependencies

- Task 3 depends on tasks 1 and 2 (columns must exist)
- Task 4 depends on task 3 (data must be backfilled)
- Tasks 5-7 depend on task 4 (constraints must exist)
- Tasks 10-12 depend on tasks 8-9 (routes and nav must exist)
- Tasks 13-14 depend on task 7 (issue_key helper must exist)

## Parallelizable Work

- Tasks 1 and 2 can run in parallel
- Tasks 10, 11, 12 can run in parallel after dependencies met
- Task 15 can run independently after task 7
