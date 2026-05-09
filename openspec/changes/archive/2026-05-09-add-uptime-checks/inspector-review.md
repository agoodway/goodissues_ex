# Inspector Review — add-uptime-checks

**Reviewed:** 2026-04-28
**Reviewer:** inspector/review-update
**Verdict:** Needs revision

## Summary

The change-local artifacts for `add-uptime-checks` are now internally consistent and aligned with the current codebase assumptions. The remaining issues are not mechanical gaps inside this change; they are cross-change ownership conflicts caused by other active changes that still define `issues` and dashboard issue UI behavior without `incident`.

Because `review-update` is scoped to this change directory, no additional patches were applied in this pass. To fully resolve the review, the in-flight `issues` and dashboard filtering/detail changes need reconciliation with this change's incident rollout.

**Counts:** Critical: 0 · Warning: 3 · Suggestion: 0

## Scope inspected

- Proposal: `openspec/changes/add-uptime-checks/proposal.md`
- Design: `openspec/changes/add-uptime-checks/design.md`
- Tasks: `openspec/changes/add-uptime-checks/tasks.md`
- Deltas:
  - `openspec/changes/add-uptime-checks/specs/uptime-checks/spec.md`
  - `openspec/changes/add-uptime-checks/specs/incident-lifecycle/spec.md`
  - `openspec/changes/add-uptime-checks/specs/bot-user/spec.md`
  - `openspec/changes/add-uptime-checks/specs/issues/spec.md`
  - `openspec/changes/add-uptime-checks/specs/issues-ui/spec.md`
- Canonical specs consulted:
  - `openspec/specs/issues-ui/spec.md`
- Other active changes consulted:
  - `openspec/changes/02-add-issues-api/specs/issues/spec.md`
  - `openspec/changes/add-issues-filtering/specs/dashboard-issues/spec.md`
  - `openspec/changes/update-issue-detail-with-errors/specs/issues-ui/spec.md`

## Critical

_None._

## Warning

1. **`issues` capability is still owned by another active change** — `openspec/changes/add-uptime-checks/specs/issues/spec.md:1`
   - **Finding:** This change uses a `MODIFIED` `issues` delta, but there is no canonical `openspec/specs/issues/spec.md` yet. The in-flight owner is still `openspec/changes/02-add-issues-api/specs/issues/spec.md`, and that active change still hardcodes `type (enum: bug, feature_request)` at `openspec/changes/02-add-issues-api/specs/issues/spec.md:70` and only defines `bug` / `feature_request` in its `Issue Type Enum` requirement at `openspec/changes/02-add-issues-api/specs/issues/spec.md:85-94`.
   - **Suggested fix:** Reconcile or supersede `02-add-issues-api` so the `issues` capability has one authoritative in-flight definition that includes `incident`.

2. **`Issue Detail View` is still owned by another active change** — `openspec/changes/add-uptime-checks/specs/issues-ui/spec.md:13`
   - **Finding:** This change modifies `Issue Detail View`, but canonical `openspec/specs/issues-ui/spec.md` does not define that requirement yet. The in-flight owner is `openspec/changes/update-issue-detail-with-errors/specs/issues-ui/spec.md:3-38`, so incident detail behavior is still split across active changes.
   - **Suggested fix:** Reconcile with `update-issue-detail-with-errors` or wait until `Issue Detail View` lands canonically before extending it from another change.

3. **Dashboard type-filter behavior still conflicts with another active change** — `openspec/changes/add-uptime-checks/specs/issues-ui/spec.md:10`
   - **Finding:** This change requires the dashboard type filter to include `incident`, but `openspec/changes/add-issues-filtering/specs/dashboard-issues/spec.md:17` still defines the type filter as `(bug, feature_request, all)`.
   - **Suggested fix:** Reconcile or supersede `add-issues-filtering` so dashboard type-filter behavior includes `incident` consistently.

## Suggestion

_None._

## Patches applied

0 findings were auto-patched. 0 findings were patched after user guidance. 0 findings were skipped.

### Auto-patched

_None._

### User-guided patches

_None._

### Skipped

_None._

## Alignment notes

- **Other active changes:** `02-add-issues-api` still owns the in-flight `issues` capability and omits `incident`; `add-issues-filtering` still omits `incident` from dashboard type filters; `update-issue-detail-with-errors` still owns the in-flight `Issue Detail View` requirement.
- **Canonical specs:** `issues-ui` canonical coverage exists only for `Issue List View` in `openspec/specs/issues-ui/spec.md:6-15`. There are still no canonical specs under `openspec/specs/` for `issues`, `uptime-checks`, `incident-lifecycle`, or `bot-user`.
- **Codebase assumptions verified:** `issues.type` is stored as `:string` in `app/priv/repo/migrations/20260127221202_create_issues.exs:5-10`; API key scopes are hardcoded today in `app/lib/app/accounts/api_key.ex:13-18` and `app/lib/app_web/live/dashboard/api_key_live/edit.ex:13-20`; `register_user/1` creates a default account in `app/lib/app/accounts.ex:77-83`; and application startup wiring still needs explicit monitoring recovery support in `app/lib/app/application.ex:11-29`.

## What looks good

- The monitoring domain split, incident lifecycle, and project-scoped API routes are coherent.
- The change now explicitly covers backend rollout, checks scopes, incident visibility in existing issue views, and keeping incident creation system-driven.
- The check member/results routes now specify project-scoping behavior and corresponding tests.
- The change-local tasks and delta specs now map cleanly to one another.
