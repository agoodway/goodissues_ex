# Inspector Review — add-heartbeat-monitoring

**Reviewed:** 2026-04-29
**Reviewer:** inspector/review-update
**Verdict:** Ready to implement

## Summary

This change adds passive heartbeat monitoring on top of the monitoring and incident infrastructure: token-auth ping endpoints, deadline workers, ping history, and rule-based alerting. The original review found gaps around hardened scheduling, incident-lifecycle ownership, token secrecy, concurrency, recovery semantics, and API contract details. Those findings were patched directly into the change artifacts, and the current rerun returns no remaining concrete findings.

**Counts:** Critical: 0 · Warning: 0 · Suggestion: 0

## Scope inspected

- Proposal: `openspec/changes/add-heartbeat-monitoring/proposal.md`
- Design: `openspec/changes/add-heartbeat-monitoring/design.md`
- Tasks: `openspec/changes/add-heartbeat-monitoring/tasks.md`
- Deltas:
  - `openspec/changes/add-heartbeat-monitoring/specs/heartbeat-monitoring/spec.md`
  - `openspec/changes/add-heartbeat-monitoring/specs/heartbeat-alerting/spec.md`
  - `openspec/changes/add-heartbeat-monitoring/specs/incident-lifecycle/spec.md`
- Canonical specs consulted:
  - none for `heartbeat-monitoring`
  - none for `heartbeat-alerting`
  - none for `incident-lifecycle`
- Other active changes consulted:
  - `openspec/changes/add-uptime-checks/proposal.md`
  - `openspec/changes/add-uptime-checks/specs/incident-lifecycle/spec.md`
  - `openspec/changes/harden-check-scheduling/proposal.md`

## Critical

_None._

## Warning

_None._

## Suggestion

_None._

## Alignment notes

- **Other active changes:** The change now coordinates explicitly with both `add-uptime-checks` and `harden-check-scheduling`, including heartbeat-specific incident handling and heartbeat-owned periodic recovery semantics.
- **Canonical specs:** There are still no canonical `heartbeat-monitoring`, `heartbeat-alerting`, or `incident-lifecycle` specs under `openspec/specs/`, so this change remains the active owner for those deltas.
- **Codebase assumptions verified:** The tasks cover current app-level integration points that do not yet exist in code today: heartbeat queue wiring, startup recovery, heartbeat API scopes, dashboard scope-editor sync, public ping OpenAPI docs, and non-check-specific incident handling.

## What looks good

- The heartbeat worker contract now imports the hardened scheduling invariants instead of repeating the original Oban chaining bug.
- `next_due_at` gives heartbeat deadlines a durable scheduling anchor across success, fail, overdue recovery, and stale-job invalidation.
- Token secrecy is now explicit: create reveals the ping URL, later management responses redact it.
- Ping/deadline transitions, `HeartbeatPing.issue_id` linkage, and delete/pause edge cases are all specified clearly enough to guide implementation.
- The API contract now covers path naming, request/response behavior, public ping docs, and reserved `exit_code` handling.
