## 1. Worker Self-Reschedule Hardening

- [x] 1.1 Refactor `FF.Monitoring.Workers.CheckRunner.perform/1` to use `try/after`, with `Scheduler.schedule_next/1` invoked from the `after` clause via a new `reschedule_if_active/1` helper that re-fetches the check and short-circuits on `nil` or `paused: true`
- [x] 1.2 Remove the `Scheduler.schedule_next/1` call from `run/1` so the body is purely "do the work"; the `after` clause owns rescheduling
- [x] 1.3 Add a regression test where `run/1` (or any function it calls) raises mid-execution and assert that a successor job is still inserted
- [x] 1.4 Add a test that a deleted check during `perform/1` does NOT enqueue a successor

## 2. Encode Unique Constraint Contract

- [x] 2.1 Confirm `CheckRunner` `unique:` config is `[keys: [:check_id], states: [:available, :scheduled, :retryable]]` (no `:executing`)
- [x] 2.2 Add a regression test that calling `Scheduler.schedule_next/1` while a job for the same check is in `:executing` state returns `{:ok, _}` with a NEW job id (not a `conflict?: true` no-op)

## 3. Scheduler Helpers

> Note: `Scheduler.orphaned_checks/0` and `Scheduler.recover_orphaned_jobs/0` already exist and are reused as-is. Tasks below add only the two NEW helpers needed by the reaper.

- [x] 3.1 Add `Scheduler.stuck_executing_jobs/1` taking `now :: DateTime.t()` and returning Oban jobs in `:executing` state for non-paused checks where `attempted_at < now - (5 * check.interval_seconds)`. Explicit `now` argument is for test determinism — the reaper passes `DateTime.utc_now/0`. Result includes the joined check so the reaper can act in one query
- [x] 3.2 Add `Scheduler.cancel_job/1` (by Oban job id) that transitions the job to `:cancelled`. Distinct from `cancel_jobs/1` which targets all jobs for a check
- [x] 3.3 Tests: `stuck_executing_jobs/1` returns nothing for fresh executing jobs; returns expected jobs once `attempted_at` is past the threshold (controlled via the `now` argument); honors `paused` state

## 4. Reaper Worker

- [x] 4.1 Create `FF.Monitoring.Workers.Reaper` Oban worker (`queue: :default`, `max_attempts: 1`)
- [x] 4.2 Implement `perform/1`:
  - Start a monotonic timer
  - Find orphans via `Scheduler.orphaned_checks/0`; for each, call `Scheduler.schedule_initial/1` and emit `[:ff, :monitoring, :reaper, :recovered]` with `reason: :orphaned`
  - Find stuck via `Scheduler.stuck_executing_jobs/1`; for each, `cancel_job/1` then `schedule_initial/1`, emit `:recovered` with `reason: :stuck`
  - Emit `[:ff, :monitoring, :reaper, :run]` with `duration_ms`, `recovered_count`, `orphan_count`, `stuck_count`
  - Broadcast `{:reaper_run_completed, %{count, by_reason}}` on `"monitoring:reaper"`
  - Return `:ok`
- [x] 4.3 Tests: reaper recovers an orphaned check; reaper cancels + reschedules a stuck job; reaper is a no-op when nothing is broken; telemetry event is emitted; PubSub event is broadcast

## 5. Cron Plugin Configuration

- [x] 5.1 In `config/config.exs`, add `plugins: [{Oban.Plugins.Cron, crontab: [{"* * * * *", FF.Monitoring.Workers.Reaper}]}]` to the `config :app, Oban` block
- [x] 5.2 In `config/test.exs`, override the Oban config with `plugins: []` so the cron plugin does not run during tests (the existing `testing: :manual, notifier: Oban.Notifiers.Isolated` config stays)
- [x] 5.3 Test: at application start (in dev/prod), `Oban.config().plugins` includes `Oban.Plugins.Cron` and the crontab references `FF.Monitoring.Workers.Reaper`. In test, `Oban.config().plugins` is empty

## 6. Observability Plumbing

- [x] 6.1 Add a `Monitoring.reaper_topic/0` returning `"monitoring:reaper"` and a `broadcast_reaper_run_completed/1` helper
- [x] 6.2 Document the telemetry event names and metadata shape in the Reaper module docstring
- [x] 6.3 Test: PubSub subscribers receive `{:reaper_run_completed, _}` exactly once per reaper run, even when count is zero

## 7. Spec & Documentation

- [x] 7.1 Verify `openspec validate harden-check-scheduling` passes
- [x] 7.2 Confirm no behaviour changes leak into the public REST API contract — this is purely an internal reliability change
