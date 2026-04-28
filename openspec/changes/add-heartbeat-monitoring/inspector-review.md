# Inspector Review — add-heartbeat-monitoring

**Reviewed:** 2026-04-28
**Reviewer:** inspector/review-update
**Verdict:** Ready to implement

## Summary

This change adds passive heartbeat monitoring on top of the uptime-check infrastructure, with public token-auth ping routes, deadline workers, ping history, and rule-based alerting. The quick review found a set of mechanical spec/code-alignment issues rather than design blockers: stale `App.*` namespaces, missing dependency/startup-recovery coverage, routing/OpenAPI generation gaps, and a success-path inconsistency around `consecutive_failures`.

All findings in this pass were auto-patched inside the change directory, and the change now reflects the current FruitFly codebase conventions and the explicit dependency on `add-uptime-checks`.

**Counts:** Critical: 4 · Warning: 5 · Suggestion: 1

## Scope inspected

- Proposal: `openspec/changes/add-heartbeat-monitoring/proposal.md`
- Design: `openspec/changes/add-heartbeat-monitoring/design.md`
- Tasks: `openspec/changes/add-heartbeat-monitoring/tasks.md`
- Deltas:
  - `openspec/changes/add-heartbeat-monitoring/specs/heartbeat-alerting/spec.md`
  - `openspec/changes/add-heartbeat-monitoring/specs/heartbeat-monitoring/spec.md`
- Canonical specs consulted:
  - none for `heartbeat-monitoring` or `heartbeat-alerting`
- Other active changes consulted:
  - `openspec/changes/add-uptime-checks/proposal.md`
  - `openspec/changes/add-uptime-checks/design.md`
  - `openspec/changes/add-uptime-checks/specs/uptime-checks/spec.md`
  - `openspec/changes/add-uptime-checks/specs/incident-lifecycle/spec.md`
  - `openspec/changes/add-uptime-checks/specs/bot-user/spec.md`

## Critical

_None._

## Warning

_None._

## Suggestion

_None._

## Patches applied

10 findings were auto-patched. 0 findings were patched after user guidance. 0 findings were skipped.

### Auto-patched

1. **Explicit prerequisite added** — `openspec/changes/add-heartbeat-monitoring/proposal.md:24` -> documented the dependency on `add-uptime-checks` in the proposal, added a prerequisite note in impact, mirrored the dependency in `design.md:5`, and added a task gate in `tasks.md:1-3`.
2. **Stale `App.*` namespaces corrected** — `openspec/changes/add-heartbeat-monitoring/design.md:3` -> renamed change-local module references from `App.*` to `FF.*` across proposal, design, and tasks so they match the actual codebase namespace.
3. **Worker placement aligned with domain namespaces** — `openspec/changes/add-heartbeat-monitoring/tasks.md:44` -> changed the deadline worker task to `FF.Monitoring.Workers.HeartbeatDeadline` and updated the proposal impact line accordingly.
4. **Success-path reset semantics made explicit** — `openspec/changes/add-heartbeat-monitoring/specs/heartbeat-monitoring/spec.md:42` -> clarified that logical success pings reset `consecutive_failures`, and updated the corresponding implementation task at `tasks.md:26`.
5. **Startup recovery covered in requirements** — `openspec/changes/add-heartbeat-monitoring/specs/heartbeat-monitoring/spec.md:105` -> added an application-restart scenario for re-enqueuing missing deadline jobs to match task `5.7`.
6. **Computed duration no longer conflicts with request payload example** — `openspec/changes/add-heartbeat-monitoring/specs/heartbeat-monitoring/spec.md:48` -> removed client-supplied `duration_ms` from the success-ping example so duration remains system-computed.
7. **Router scope placement clarified** — `openspec/changes/add-heartbeat-monitoring/tasks.md:57` -> split route tasks so management routes stay in authenticated `/api/v1` scopes and ping routes explicitly use the public `:api` pipeline at `tasks.md:64`.
8. **API key scope sync requirement tightened** — `openspec/changes/add-heartbeat-monitoring/tasks.md:58` -> updated the scope task so the dashboard scope editor stays aligned with the same scope list/source of truth.
9. **Controller task pattern aligned with existing API structure** — `openspec/changes/add-heartbeat-monitoring/tasks.md:55` -> added `HeartbeatJSON` / `HeartbeatPingJSON` rendering tasks and clarified ping-history rendering reuse.
10. **OpenAPI generation flow corrected** — `openspec/changes/add-heartbeat-monitoring/proposal.md:35` -> updated the proposal and tasks (`tasks.md:76-78`) to treat OpenApiSpex controller/schema metadata as the source of truth, regenerate `app/openapi.json` via `mix openapi.spec`, and mark public ping operations with `security: []`.

### User-guided patches

_None._

### Skipped

_None._

## Alignment notes

- **Other active changes:** `add-heartbeat-monitoring` still depends on `add-uptime-checks` for `FF.Monitoring`, incident-lifecycle behavior, and bot-user flow, but that dependency is now explicit in the proposal, design, and tasks.
- **Canonical specs:** there are no canonical `heartbeat-monitoring` or `heartbeat-alerting` specs under `openspec/specs/`, so this change remains the in-flight owner for those capabilities.
- **Codebase assumptions verified:** current application code uses `FF.*` / `FFWeb.*` namespaces; router auth is split across `:api`, `:api_authenticated`, and `:api_write` in `app/lib/app_web/router.ex`; Oban queues are configured in `app/config/config.exs`; startup supervision is in `app/lib/app/application.ex`; API key scopes are hardcoded in `app/lib/app/accounts/api_key.ex` and `app/lib/app_web/live/dashboard/api_key_live/edit.ex`; OpenAPI is generated from `FFWeb.ApiSpec` and controller/schema metadata via `app/lib/mix/tasks/openapi.ex`.

## What looks good

- The change cleanly separates heartbeat monitoring from active uptime checks while reusing the incident lifecycle instead of inventing a parallel alerting path.
- The heartbeat-monitoring and heartbeat-alerting deltas cover the core CRUD, ping, deadline, alert-rule, and history behaviors with concrete scenarios.
- The design is specific about token auth, duration computation, and self-rescheduling deadline workers, which makes the implementation path straightforward.
- After patching, the tasks map much more directly to the current Phoenix router, OpenApiSpex, Oban, and API key scope patterns in the codebase.
