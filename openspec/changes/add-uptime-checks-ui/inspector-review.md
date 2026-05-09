# Inspector Review — add-uptime-checks-ui

**Reviewed:** 2026-04-29
**Reviewer:** inspector/review-update
**Verdict:** Ready to implement

## Summary

This change adds a dashboard UI for uptime checks, plus the backend support that UI depends on for realtime updates and accurate runtime status. The original artifacts were directionally strong but mixed backend monitoring behavior into the UI-only capability, left a critical runtime-status prerequisite unspecified, and had a handful of consistency gaps around routes, empty states, and labels. Those findings were patched directly into the change artifacts during this review-update pass.

**Counts:** Critical: 1 · Warning: 7 · Suggestion: 0

## Scope inspected

- Proposal: `openspec/changes/add-uptime-checks-ui/proposal.md`
- Design: `openspec/changes/add-uptime-checks-ui/design.md`
- Tasks: `openspec/changes/add-uptime-checks-ui/tasks.md`
- Deltas:
  - `openspec/changes/add-uptime-checks-ui/specs/uptime-checks-ui/spec.md`
  - `openspec/changes/add-uptime-checks-ui/specs/uptime-checks/spec.md`
- Canonical specs consulted:
  - None for `uptime-checks-ui`
  - None for `uptime-checks`
- Other active changes consulted: `add-uptime-checks`

## Critical

_None._

## Warning

_None._

## Suggestion

_None._

## Patches applied

7 findings were auto-patched. 1 finding was patched after user guidance. 0 findings were skipped.

### Auto-patched

1. **Moved backend monitoring behavior into the correct capability** — `openspec/changes/add-uptime-checks-ui/proposal.md:20`
   - Added `uptime-checks` under Modified Capabilities, softened the backend-completeness claim, and created `openspec/changes/add-uptime-checks-ui/specs/uptime-checks/spec.md:1` so PubSub lifecycle behavior no longer lives only in the UI delta.

2. **Covered the failed-run status gap the UI depends on** — `app/lib/app/monitoring/workers/check_runner.ex:158`
   - Added an explicit task and spec delta at `openspec/changes/add-uptime-checks-ui/tasks.md:14` and `openspec/changes/add-uptime-checks-ui/specs/uptime-checks/spec.md:6` requiring failed checks to persist `status: :down` for accurate dashboard state.

3. **Normalized the dashboard route contract** — `openspec/changes/add-uptime-checks-ui/tasks.md:18`
   - Rewrote task `3.1` to use the full nested `/projects/:project_id/checks/...` paths described by the design and UI spec.

4. **Clarified that check pages reuse existing projects navigation** — `openspec/changes/add-uptime-checks-ui/tasks.md:19`
   - Replaced the implied layout work with the actual requirement to use the existing `active_nav: :projects` assignment, and aligned the proposal impact note at `openspec/changes/add-uptime-checks-ui/proposal.md:30`.

5. **Made empty states consistent with authorization rules** — `openspec/changes/add-uptime-checks-ui/specs/uptime-checks-ui/spec.md:22`
   - Split empty-state behavior so managers get create CTAs while non-managers get a view-only state, and aligned the implementation tasks at `openspec/changes/add-uptime-checks-ui/tasks.md:28` and `openspec/changes/add-uptime-checks-ui/tasks.md:64`.

6. **Removed the redundant project field from the create-form design** — `openspec/changes/add-uptime-checks-ui/design.md:63`
   - Updated the design so the project comes from the route context instead of being a selectable basic field.

7. **Aligned summary and event-contract details across artifacts** — `openspec/changes/add-uptime-checks-ui/design.md:49`
   - Defined paused/unknown sidebar-summary behavior and prefix-based breadcrumbs at `openspec/changes/add-uptime-checks-ui/design.md:91` and `openspec/changes/add-uptime-checks-ui/specs/uptime-checks-ui/spec.md:113`, and normalized the delete-broadcast payload contract in `openspec/changes/add-uptime-checks-ui/tasks.md:4` and `openspec/changes/add-uptime-checks-ui/specs/uptime-checks/spec.md:17`.

### User-guided patches

1. **Standardized the project sidebar card label** — `openspec/changes/add-uptime-checks-ui/proposal.md:13`
   - Renamed the card to `Monitoring` to match the rest of the change set (user chose: `Monitoring`).

### Skipped

_None._

## Alignment notes

- **Other active changes:** Consistent after patching. The change now expresses backend monitoring work under a modified `uptime-checks` delta instead of leaving those SHALLs only inside `uptime-checks-ui`, which aligns better with `openspec/changes/add-uptime-checks/specs/uptime-checks/spec.md`.
- **Canonical specs:** No canonical `uptime-checks-ui` or `uptime-checks` spec exists yet under `openspec/specs/`, so consistency was checked against active change artifacts and the current codebase instead.
- **Codebase assumptions verified:** No dashboard check LiveViews or dashboard check routes exist today; `FF.Monitoring.list_check_results/4` exists but has no status filter support; `FFWeb.Dashboard.ProjectLive.Show` has no monitoring card; and failed check executions currently do not persist `status: :down` in `app/lib/app/monitoring/workers/check_runner.ex:158`.

## What looks good

- The change already had a clear project-scoped routing model that matches the existing API nesting.
- The tasks break the work into sensible backend, routing, LiveView, and test layers.
- The UI spec is explicit about permission gating, realtime updates, and the edit-via-modal interaction model.
- Reusing the project show page as the entry point is consistent with the existing dashboard information architecture.
