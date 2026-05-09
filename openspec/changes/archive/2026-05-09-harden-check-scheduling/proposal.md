## Why

Uptime check execution depends on a single self-rescheduling Oban worker chain. We just diagnosed two failure modes that broke the chain in production-like conditions:

1. The worker's `unique` constraint included `:executing`, which caused the in-flight job to match its own self-reschedule. The new insert was silently swallowed and the chain stopped.
2. Even with that fixed, ANY exception between `create_check_result` and `Scheduler.schedule_next` permanently halts the chain until the next application restart.

The chain is currently recovered only at boot via `Scheduler.recover_orphaned_jobs/0`. There is no defense between deploys. A monitoring system that silently stops monitoring is the worst kind of failure — checks may go hours or days without running while users assume coverage is intact.

## What Changes

- Harden `CheckRunner.perform/1` so `Scheduler.schedule_next/1` always runs (`try/after`) — moving the reschedule out of `run/1` so it can no longer be skipped by an exception in the body.
- Encode the `unique` constraint fix (drop `:executing` from the unique `states` list) as a requirement so future contributors do not regress it.
- Add `GI.Monitoring.Workers.Reaper` Oban worker scheduled every 60s via `Oban.Plugins.Cron`. This is **additive** to the existing boot-time `Scheduler.recover_orphaned_jobs/0` recovery — boot recovery is preserved unchanged; the reaper provides defense between deploys.
- Reaper recovers two failure modes:
  - **Orphans** — active checks with no pending Oban job → `Scheduler.schedule_initial/1`
  - **Stuck** — jobs in `:executing` state with `attempted_at < now - (5 × interval_seconds)` → cancel and reschedule
- Emit `[:ff, :monitoring, :reaper, :run]` and `[:ff, :monitoring, :reaper, :recovered]` telemetry events.
- Broadcast a single `{:reaper_run_completed, %{count, by_reason}}` PubSub event per run on the global `"monitoring:reaper"` topic.

## Capabilities

### Modified Capabilities

- `uptime-checks`: Add reliability requirements covering unconditional worker self-reschedule, the unique-constraint contract, and a periodic reaper for orphan/stuck recovery with telemetry and PubSub observability.

## Impact

- **`GI.Monitoring.Workers.CheckRunner`**: refactor `perform/1` into `try/after` shape; move `Scheduler.schedule_next` out of `run/1`.
- **`GI.Monitoring.Scheduler`**: add helpers to list stuck-executing jobs and to cancel a specific job by id.
- **New module `GI.Monitoring.Workers.Reaper`**: queries orphans + stuck, performs recovery, emits telemetry and PubSub.
- **Application config**: register `Oban.Plugins.Cron` with the reaper schedule.
- **Telemetry**: two new event names under `[:ff, :monitoring, :reaper, …]`.
- **PubSub**: new global topic `"monitoring:reaper"` with one event type.
