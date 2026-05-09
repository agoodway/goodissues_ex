# Inspector review-update — `harden-check-scheduling`

**Date:** 2026-04-29
**Reviewer:** Inspector (review-update)
**Verdict:** ✅ Ready — all findings resolved

## Method

Two parallel agents: a structural/consistency pass and a codebase-alignment pass. Both audited the change against the in-tree codebase and against the baseline `uptime-checks` deltas in completed-but-unarchived sibling changes (`add-uptime-checks`, `add-uptime-checks-ui`).

## Patches applied

9 findings were auto-patched. 2 findings were patched after user guidance. 0 findings were skipped.

### Auto-patched

1. **Wrong reference to `:executing` removal location** — `proposal.md:13` → changed "drop `:executing` from `keys`" to "drop `:executing` from the unique `states` list". The unique constraint's `keys` is `[:check_id]` and never changed; what changed was the `states` list.
2. **Boot-recovery preservation unstated** — `proposal.md:14` → added explicit note that the periodic reaper is **additive** to the existing boot-time `Scheduler.recover_orphaned_jobs/0`, not a replacement.
3. **Orphan vs stuck path distinction unstated** — `design.md` (Reaper decision) → added paragraph explaining that `orphaned_checks/0` already counts `:executing` as a pending state, so stuck-executing jobs are not double-recovered by both paths. The two paths are non-overlapping by construction.
4. **`Scheduler.orphaned_checks/0` reuse not flagged** — `tasks.md` (section 3 header) → added note that `orphaned_checks/0` and `recover_orphaned_jobs/0` already exist and are reused; the section's tasks add only the two NEW helpers.
5. **Multi-assertion THEN clause in "no-op" scenario** — `specs/uptime-checks/spec.md` → split the bundled negative + observability assertion. The no-op scenario now focuses purely on the no-enqueue assertion; observability is owned by the next requirement which already covers always-emit.
6. **Telemetry verb "executed" → "emitted"** — `specs/uptime-checks/spec.md` (two scenarios) → telemetry events are emitted/dispatched, not executed. Aligned wording with `design.md`.
7. **Cron plugin location ambiguous** — `tasks.md:33-35` (split into question 2 below).

### User-guided patches

1. **`stuck_executing_jobs` arity** (Question 1) — user chose **Option B**: `stuck_executing_jobs/1` taking `now :: DateTime.t()` for deterministic testing.
   - `tasks.md:15-17` → updated to specify the explicit `now` argument and that the reaper passes `DateTime.utc_now/0`.
   - `design.md` → added inline note about the signature in the Reaper decision section.

2. **Cron plugin registration location** (Question 2) — user chose **Option A**: register in `config/config.exs`, override `plugins: []` in `config/test.exs`.
   - `tasks.md:33-35` → replaced the contradictory tasks 5.1/5.2 with concrete steps. 5.1 adds the plugin in `config.exs`, 5.2 overrides to `plugins: []` in `test.exs` while preserving existing `testing: :manual` + `notifier: Oban.Notifiers.Isolated`. 5.3 specifies the test assertion: `Oban.config().plugins` includes `Oban.Plugins.Cron` in dev/prod, empty in test.

### Skipped

None.

## Findings (resolved → above)

All findings from this review are addressed in the Patches Applied section above. No outstanding Critical, Warning, or Suggestion findings remain.

## Observations not requiring action

- **Codebase already partially aligned:** `lib/app/monitoring/workers/check_runner.ex:12-15` already has `unique` states as `[:available, :scheduled, :retryable]` (the `:executing` removal was already applied in the working tree as a hot-fix). This change encodes that fix as a spec requirement so it can't be regressed.
- **`Oban.Plugins.Cron` availability:** Verified `oban_pro` is not in deps; Oban OSS 2.x ships `Oban.Plugins.Cron` natively. No new dependency required.
- **`add-heartbeat-monitoring`** (in-progress) creates new `heartbeat-monitoring` and `heartbeat-alerting` capabilities. It does NOT touch `uptime-checks` and does not conflict with this change.
- **Boot recovery + reaper are idempotent:** Both paths terminate in `Scheduler.schedule_initial/1` → `Oban.insert/1`, which honours the unique constraint (states `[:available, :scheduled, :retryable]`). Even if both fire concurrently for the same check, only one job lands.

## Validation

```
$ openspec validate harden-check-scheduling
Change 'harden-check-scheduling' is valid
```

## Verdict

**Ready for `/takeoff` or implementation.** All 11 findings (9 mechanical + 2 design) have been resolved in the proposal/design/tasks/spec artifacts. The change is internally consistent, aligned with the codebase, and conflict-free against other active changes.
