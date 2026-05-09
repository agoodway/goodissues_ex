# Inspector Review — add-heartbeat-monitoring

**Reviewed:** 2026-05-09
**Reviewer:** inspector/review
**Verdict:** Blocked

## Summary

This change is well specified: the proposal, design, tasks, and delta specs cover heartbeat CRUD, token-auth ping flows, alert rules, deadline recovery, and heartbeat-specific incident handling in enough detail to guide implementation. The blocker is not missing heartbeat detail, but the change's own declared prerequisite on hardened monitoring scheduling. `add-heartbeat-monitoring` says heartbeat deadlines must inherit the invariants from `harden-check-scheduling`, but the current codebase still uses the older best-effort check chain without periodic reaper recovery.

**Counts:** Critical: 1 · Warning: 0 · Suggestion: 0

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
  - `openspec/changes/harden-check-scheduling/proposal.md`

## Critical

1. **Declared scheduling prerequisite is still unresolved** — `openspec/changes/add-heartbeat-monitoring/tasks.md:4`
   - **Finding:** The change says implementation must wait for or reconcile `harden-check-scheduling`, but the current monitoring code still lacks the hardened invariants that heartbeat deadlines are supposed to inherit.
   - **Evidence:** The change marks this as a dependency in `openspec/changes/add-heartbeat-monitoring/proposal.md:38`, `openspec/changes/add-heartbeat-monitoring/design.md:7`, and `openspec/changes/add-heartbeat-monitoring/tasks.md:4`. In the live code, `FF.Monitoring.Workers.CheckRunner` still schedules the next job only after the body completes (`app/lib/app/monitoring/workers/check_runner.ex:45-58`), `FF.Monitoring.Scheduler` only performs boot-time orphan recovery (`app/lib/app/monitoring/scheduler.ex:74-81`), and there is no heartbeat-analogous or check-side periodic reaper worker registered in application startup (`app/lib/app/application.ex:42-56`). That does not yet satisfy the hardened contract described in `openspec/changes/harden-check-scheduling/proposal.md:12-18`.
   - **Suggested fix:** Do not start heartbeat implementation until `harden-check-scheduling` lands, or explicitly fold those hardening changes into the heartbeat implementation plan and update task 0.2 to reflect that reconciliation.

## Warning

_None._

## Suggestion

_None._

## Clarifying questions

_None._

## Alignment notes

- **Other active changes:** `add-heartbeat-monitoring` cleanly layers on top of the uptime-check infrastructure already present in code (`app/lib/app/monitoring.ex:1-10`, `app/lib/app/monitoring/scheduler.ex:1-10`), and it explicitly declares both `add-uptime-checks` and `harden-check-scheduling` as dependencies (`openspec/changes/add-heartbeat-monitoring/proposal.md:38`). I found no separate active change that conflicts with the heartbeat API surface itself.
- **Canonical specs:** There are still no canonical specs under `openspec/specs/` for `heartbeat-monitoring`, `heartbeat-alerting`, or `incident-lifecycle`, so this change remains the active owner for those requirements.
- **Codebase assumptions verified:** `FF.Monitoring` exists and already owns checks (`app/lib/app/monitoring.ex:1-18`); incident handling exists but is check-specific (`app/lib/app/monitoring/incident_lifecycle.ex:13-17`, `app/lib/app/monitoring/incident_lifecycle.ex:127-138`); API key scopes already include checks and would need heartbeat scope expansion (`app/lib/app/accounts/api_key.ex:13-19`); the dashboard scope editor also hardcodes the current scope list (`app/lib/app_web/live/dashboard/api_key_live/edit.ex:13-22`).

## What looks good

- The heartbeat change is specific about token secrecy: create returns the ping URL, while later management reads redact token-bearing fields.
- Ping reception, deadline execution, and incident transitions are intentionally serialized, which is the right shape for avoiding ping-vs-deadline races.
- The design correctly treats heartbeat incidents as a new wrapper or generalized path rather than pretending the current check-specific lifecycle can be reused unchanged.
- The tasks cover the full vertical slice: schema, context, workers, API, scopes, OpenAPI, and tests.
