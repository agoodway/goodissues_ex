# Tasks

## Phase 1: Database Schema

- [x] Create migration for errors table with indexes
- [x] Create migration for occurrences table with indexes
- [x] Create migration for stacktrace_lines table with indexes
- [x] Run migrations and verify schema

## Phase 2: Ecto Schemas

- [x] Create Error schema with Ecto.Enum for status
- [x] Create Occurrence schema with map and array fields
- [x] Create StacktraceLine schema with position ordering
- [x] Add `has_one :error` to Issue schema
- [x] Write schema unit tests

## Phase 3: Context Functions

- [x] Add `get_error_by_fingerprint/2` to Tracking context
- [x] Add `create_error/2` with occurrence and stacktrace lines
- [x] Add `add_occurrence/2` that updates last_occurrence_at
- [x] Add `report_error/3` with fingerprint deduplication logic
- [x] Add `list_errors/2` with status and muted filters
- [x] Add `get_error_with_occurrences/3` with pagination
- [x] Add `search_errors_by_stacktrace/3` for module/function/file search
- [x] Add `update_error/2` for status and muted updates
- [x] Write context unit tests

## Phase 4: API Layer

- [x] Create ErrorController with index, show, create, update, search actions
- [x] Create ErrorJSON view module
- [x] Add routes to router under /api/v1/errors
- [ ] Update OpenAPI spec with error endpoints (schemas)
- [ ] Write controller tests

## Phase 5: Verification

- [x] Test fingerprint deduplication flow end-to-end (via context tests)
- [ ] Test stacktrace search queries use indexes (EXPLAIN ANALYZE)
- [x] Test cascade deletion behavior (via context tests)
- [x] Test account scoping for all operations (via context tests)
- [ ] Manual API testing with curl
