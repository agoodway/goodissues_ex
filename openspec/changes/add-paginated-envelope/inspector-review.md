# Inspector Review: add-paginated-envelope

**Date**: 2026-04-28
**Type**: review-update (quick review + auto-patch)
**Verdict**: Ready (after patches applied)

## Summary

Reviewed all change artifacts (proposal, design, tasks, delta spec) against canonical specs, other active changes, and codebase state. Found 20 findings across two review passes (structural/consistency + codebase alignment).

**Original counts**: 3 Critical, 10 Warning, 7 Suggestion
**After patching**: 0 Critical, 0 Warning, 0 Suggestion remaining

## Patches applied

10 findings were auto-patched. 4 findings were patched after user guidance. 0 findings were skipped.

### Auto-patched

1. **Empty Modified Capabilities** — `proposal.md:21` → Added `error-tracking` to Modified Capabilities section
2. **Missing MODIFIED delta spec for error-tracking** — created `specs/error-tracking/spec.md` with MODIFIED scenarios for search and list endpoints
3. **Inaccurate design assumption** — `design.md:64` → Fixed claim that `search_errors_by_stacktrace/2` "loads all into memory" — it already uses LIMIT/OFFSET, the real issue is the controller hardcoding meta values
4. **Per_page clamping not called out in tasks** — `tasks.md:2.1` → Added note that `extract_pagination/1` already handles clamping
5. **No-filter guard missing from task** — `tasks.md:4.1` → Added explicit note to ensure pagination applies even with no filters
6. **No task to verify list_projects/1 callers** — `tasks.md` → Added task 2.5 to verify existing callers are unaffected
7. **Task 3.4 ordering ambiguous** — `tasks.md:3.4` → Added note linking it to 3.1 controller update and `build_filters/1`
8. **No CLI behavioral test task** — `tasks.md` → Added task 6.5 for CLI smoke test
9. **No test update tasks for existing tests** — `tasks.md` → Added task 6.6 for updating controller test assertions to check `meta`
10. **total_pages floor behavior** — Verified against codebase: `max(ceil(total / per_page), 1)` at `tracking.ex:219` confirms `total_pages: 1` for empty results matches spec. No patch needed (confirmed correct).

### User-guided patches

1. **Orphan verification tasks** — `tasks.md:6.1-6.4` → Kept as-is (user chose: useful implementation reminders even without spec backing)
2. **add-uptime-checks dependency** — `proposal.md` → Added dependency note that uptime-checks should use shared PaginationMeta once this change lands (user chose: add dependency note)
3. **Go CLI function return types** — `tasks.md:5.2-5.3` → Updated tasks to return full `*ListResponse` types matching the existing `ListErrors` pattern (user chose: return full response)
4. **Invalid pagination parameter handling** — `specs/paginated-envelope/spec.md` + `tasks.md:1.5` → Added spec scenarios and task for 400 Bad Request on invalid page/per_page values (user chose: add 400 error handling)

## Codebase alignment notes

The following codebase observations were confirmed during review and are correctly addressed by the change's tasks:

- `PaginationMeta` lives in `FFWeb.Api.V1.Schemas.Error` at `schemas/error.ex:292` — task 1.2 addresses extraction
- `IssueController.index` discards pagination meta at `issue_controller.ex:47` — task 3.1 addresses this
- `ProjectController.index` calls `list_projects/1` (no pagination) at `project_controller.ex:28` — task 2.2 addresses this
- `ErrorController.search` hardcodes `page: 1, per_page: 20, total_pages: 1` at `error_controller.ex:282-290` — task 4.2 addresses this
- `extract_pagination/1` is `defp` (private) at `tracking.ex:238` — this is fine since new paginated functions will be in the same module
- Go CLI `ProjectListResponse` and `IssueListResponse` lack `Meta` field at `client.go:95-97,126-128` — tasks 5.1-5.2 address this
