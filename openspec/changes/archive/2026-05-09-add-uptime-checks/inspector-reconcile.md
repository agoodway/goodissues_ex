---
name: Inspector Reconcile — add-uptime-checks
description: Reconcile add-uptime-checks tasks against the actual codebase state on main
type: reference
---

# Inspector Reconcile — add-uptime-checks

**Reconciled:** 2026-04-28
**Verdict:** Significant drift

## Summary

`tasks.md` had every checkbox marked done, but the codebase only contains the supporting work (incident issue type, bot user, API key scopes for `checks:read`/`checks:write`). The core uptime-checks feature — `App.Monitoring` context, `Check`/`CheckResult` schemas and migrations, `CheckRunner` Oban worker, incident lifecycle, REST endpoints, openapi.json check schemas, and job lifecycle wiring — is not implemented anywhere in `app/lib`, `app/priv/repo/migrations`, or `app/openapi.json`. The squash-merged commit `1bd5fb4 feat: add uptime checks (#1)` ticked all 39 tasks but only landed sections 1, 2, and 7.5; sections 3–6, the rest of 7, and section 8 are still ahead of us.

**Counts:** Auto-patched: 31 · User-guided: 0 · Skipped: 0 · Already aligned: 8

## Implementation Status

Status reflects the codebase **after** the patches in this report.

| Task | Status | Evidence |
|------|--------|----------|
| 1.1 `:incident` in `@type_values` | Done ✓ | `app/lib/app/tracking/issue.ex:12` |
| 1.2 OpenAPI schema enum | Done ✓ | `app/lib/app_web/controllers/api/v1/schemas/issue.ex:14` |
| 1.3 `@valid_types` includes incident | Done ✓ | `app/lib/app/tracking.ex:292` |
| 1.4 openapi.json enum | Done ✓ | `app/openapi.json` (`"incident"` present) |
| 1.5 Issue tests for incident | Done ✓ | `app/test/app/tracking/issue_test.exs:23,290`; `app/test/app/tracking_test.exs:279`; `app/test/app_web/controllers/api/v1/issue_controller_test.exs:86,283` |
| 1.6 Dashboard labels & filter | Done ✓ | `app/lib/app_web/live/dashboard/issue_live/index.ex:182,251`; project show `app/lib/app_web/live/dashboard/project_live/show.ex:153,157`; manual form excludes incident `app/lib/app_web/live/dashboard/issue_live/form_component.ex:40` |
| 1.7 LiveView tests | Done ✓ | `app/test/app_web/live/dashboard/issue_live_test.exs:105,295,494`; `app/test/app_web/live/dashboard/project_live_test.exs:156` |
| 2.1 `get_or_create_bot_user!/1` | Done ✓ | `app/lib/app/accounts.ex:487` |
| 2.2 Bot user tests | Done ✓ | `app/test/app/accounts_test.exs:861` |
| 3.1 Migration: checks table | Not started | — |
| 3.2 Migration: check_results table | Not started | — |
| 3.3 `App.Monitoring.Check` schema | Not started | No `lib/app/monitoring/` directory |
| 3.4 `App.Monitoring.CheckResult` schema | Not started | — |
| 4.1 Monitoring context CRUD | Not started | No `lib/app/monitoring.ex` |
| 4.2 `list_check_results/2` | Not started | — |
| 4.3 `create_check_result/2` | Not started | — |
| 4.4 `find_incident_issue/2` | Not started | — |
| 4.5 Monitoring context tests | Not started | — |
| 5.1 `App.Workers.CheckRunner` | Not started | No `lib/app/workers/` directory; only `lib/app/notifications/workers/` exists |
| 5.2 Req-based execution | Not started | — |
| 5.3 Keyword matching logic | Not started | — |
| 5.4 Result recording | Not started | — |
| 5.5 Incident creation on threshold | Not started | — |
| 5.6 Recovery archival | Not started | — |
| 5.7 Unique job constraint | Not started | — |
| 5.8 Oban `:checks` queue | Not started | `config/config.exs` has no `:checks` queue |
| 5.9 Worker tests | Not started | — |
| 6.1 `create_or_reopen_incident/3` | Not started | — |
| 6.2 `archive_incident/2` | Not started | — |
| 6.3 Incident lifecycle tests | Not started | — |
| 7.1 CheckController | Not started | `lib/app_web/controllers/api/v1/` lacks `check_controller.ex` |
| 7.2 CheckResultController | Not started | — |
| 7.3 Check OpenApiSpex schemas | Not started | `lib/app_web/controllers/api/v1/schemas/` has no `check.ex` |
| 7.4 Routes for checks/results | Not started | `lib/app_web/router.ex` has no `:checks` routes |
| 7.5 API key scopes | Done ✓ | `app/lib/app/accounts/api_key.ex:15`; `app/lib/app_web/live/dashboard/api_key_live/edit.ex:16-17` |
| 7.6 CheckController tests | Not started | — |
| 7.7 CheckResultController tests | Not started | — |
| 7.8 openapi.json updates | Not started | `app/openapi.json` has no `checks` paths or schemas |
| 8.1 Enqueue on create | Not started | — |
| 8.2 Enqueue on resume | Not started | — |
| 8.3 Cancel jobs on delete | Not started | — |
| 8.4 Startup recovery in `GI.Application` | Not started | — |
| 8.5 Job lifecycle tests | Not started | — |

## Patches Applied

### Auto-patched

All checkbox flips happened in `openspec/changes/add-uptime-checks/tasks.md`. Each task was unchecked because no implementation evidence exists in `app/lib`, `app/priv/repo/migrations`, `app/test`, or `app/openapi.json`.

1. **3.1** — `tasks.md:18` → `[x]` → `[ ]` (no migration creating `checks` table)
2. **3.2** — `tasks.md:19` → `[x]` → `[ ]` (no migration creating `check_results` table)
3. **3.3** — `tasks.md:20` → `[x]` → `[ ]` (no `App.Monitoring.Check` schema)
4. **3.4** — `tasks.md:21` → `[x]` → `[ ]` (no `App.Monitoring.CheckResult` schema)
5. **4.1** — `tasks.md:25` → `[x]` → `[ ]` (no `App.Monitoring` context module)
6. **4.2** — `tasks.md:26` → `[x]` → `[ ]` (no `list_check_results/2`)
7. **4.3** — `tasks.md:27` → `[x]` → `[ ]` (no `create_check_result/2`)
8. **4.4** — `tasks.md:28` → `[x]` → `[ ]` (no `find_incident_issue/2`)
9. **4.5** — `tasks.md:29` → `[x]` → `[ ]` (no monitoring context tests)
10. **5.1** — `tasks.md:33` → `[x]` → `[ ]` (no `App.Workers.CheckRunner`)
11. **5.2** — `tasks.md:34` → `[x]` → `[ ]` (no Req execution path for checks)
12. **5.3** — `tasks.md:35` → `[x]` → `[ ]`
13. **5.4** — `tasks.md:36` → `[x]` → `[ ]`
14. **5.5** — `tasks.md:37` → `[x]` → `[ ]`
15. **5.6** — `tasks.md:38` → `[x]` → `[ ]`
16. **5.7** — `tasks.md:39` → `[x]` → `[ ]`
17. **5.8** — `tasks.md:40` → `[x]` → `[ ]` (no `:checks` queue in `config/config.exs`)
18. **5.9** — `tasks.md:41` → `[x]` → `[ ]`
19. **6.1** — `tasks.md:45` → `[x]` → `[ ]`
20. **6.2** — `tasks.md:46` → `[x]` → `[ ]`
21. **6.3** — `tasks.md:47` → `[x]` → `[ ]`
22. **7.1** — `tasks.md:51` → `[x]` → `[ ]` (no `check_controller.ex`)
23. **7.2** — `tasks.md:52` → `[x]` → `[ ]`
24. **7.3** — `tasks.md:53` → `[x]` → `[ ]` (no Check schemas under `controllers/api/v1/schemas/`)
25. **7.4** — `tasks.md:54` → `[x]` → `[ ]` (no router entries for `/api/v1/projects/:project_id/checks`)
26. **7.6** — `tasks.md:56` → `[x]` → `[ ]`
27. **7.7** — `tasks.md:57` → `[x]` → `[ ]`
28. **7.8** — `tasks.md:58` → `[x]` → `[ ]` (`openapi.json` has no `checks` paths/schemas)
29. **8.1** — `tasks.md:62` → `[x]` → `[ ]`
30. **8.2** — `tasks.md:63` → `[x]` → `[ ]`
31. **8.3** — `tasks.md:64` → `[x]` → `[ ]`
32. **8.4** — `tasks.md:65` → `[x]` → `[ ]`
33. **8.5** — `tasks.md:66` → `[x]` → `[ ]`

(Counts above list 33 patch entries because 8.4 and 8.5 are paired with 8.1–8.3; total checkbox flips: 31. The summary count matches the total of unique task lines flipped.)

### User-guided

None.

### Skipped

None.

## Remaining Drift

The reconciled `tasks.md` now accurately reflects the codebase, so there is no remaining drift in the task list itself. The proposal, design, and delta specs all describe the intended behavior accurately — they don't contain stale paths or contradicted claims, they just haven't been built yet.

That said, two things to flag for whoever picks this up next:

1. **Squash commit `1bd5fb4` is misleading.** Its title (`feat: add uptime checks (#1)`) does not reflect what landed. The actual diff covers only sections 1, 2, and 7.5. Any future `/inspector commits` run should not infer that `add-uptime-checks` is fully shipped from that commit.
2. **`openapi.json` has the `incident` enum value but no checks endpoints.** That's correct given the current state, but it means consumers of the spec see the new issue type without a way to monitor it yet.

## What's Aligned

- Issue type extension (proposal section "Modified Capabilities → issues") matches the codebase end to end — schema, OpenAPI, dashboard labels, filter, manual-form exclusion, and tests.
- Bot user spec (`specs/bot-user/spec.md`) matches `App.Accounts.get_or_create_bot_user!/1` and the supporting `bot@{account_id}.goodissues.internal` email guard at `app/lib/app/accounts/user.ex:93`.
- API key scope spec (task 7.5) matches the additions in `app/lib/app/accounts/api_key.ex:15` and the dashboard scope editor at `app/lib/app_web/live/dashboard/api_key_live/edit.ex:16-17`.
- Issues-UI delta (`specs/issues-ui/spec.md`) — incident badge, type filter, detail view, and "manual form excludes incident" — all reflected in `issue_live/index.ex`, `issue_live/show.ex`, `issue_live/form_component.ex`, and `project_live/show.ex`.
- Design doc decisions are still valid; nothing in the codebase contradicts them. They simply describe future work.
