## Context

The CheckRunner worker self-reschedules at the end of `perform/1`. We just observed a real outage: the unique constraint on `[:check_id]` with `states: [..., :executing]` caused the in-flight job to match its own re-enqueue, which Oban silently treats as a conflict (`conflict?: true`) and skips. The chain stopped after a single run.

That specific bug is fixed in the working tree (drop `:executing` from `states`). But the chain has a structural fragility independent of the unique constraint: the body of `run/1` can raise (DB hiccup, broadcast crash, future code) between recording the result and rescheduling, and the chain stops permanently until the next app restart.

A monitoring system that silently stops monitoring is the worst kind of failure. Defense in depth is justified here.

## Goals

1. The worker MUST reschedule the next run regardless of whether `run/1` succeeded or raised — as long as the check still exists and is not paused.
2. A periodic reaper MUST detect and recover broken chains within ~60 seconds.
3. Operators MUST have machine-readable signals (telemetry) and live signals (PubSub) when reaper activity occurs, so high reaper activity becomes a visible upstream-bug smell.

## Non-Goals

- **Interval drift detection**: if a user lowers a check's interval while a job is already scheduled for the old cadence, the reaper does NOT cancel + reschedule it. The next natural run will pick up the new interval. Adds a third axis without strong evidence we need it.
- **Watchdog for the reaper itself**: if `Oban.Plugins.Cron` stops scheduling the reaper, no internal mechanism notices. Out of scope; that's an operational/external-monitoring concern.

## Decisions

### Decision: Move `Scheduler.schedule_next/1` into `perform/1`'s `after` clause

**Shape:**

```elixir
def perform(%Oban.Job{args: %{"check_id" => check_id}}) do
  try do
    run_if_active(check_id)
  after
    reschedule_if_active(check_id)
  end
end

defp run_if_active(check_id), do: ...   # delegates to existing run/1
defp reschedule_if_active(check_id) do
  case Repo.get(Check, check_id) do
    nil               -> :ok
    %Check{paused: true} -> :ok
    check             -> Scheduler.schedule_next(check)
  end
end
```

**Why:** Eliminates "did we get far enough to reschedule?" The contract becomes "the worker reschedules unless the check is gone or paused, period." Future code added inside `run/1` can fail freely without breaking the chain.

**Tradeoff:** One additional `Repo.get(Check, ...)` per run (in the `after`). Acceptable — `run/1` already calls `refresh_check/1` after `apply_outcome`. The extra read is in the hundreds of microseconds.

### Decision: Reaper detects orphans and stuck-executing only

**Orphan:** non-paused check with zero matching jobs in `[:available, :scheduled, :retryable, :executing]`. Action: `Scheduler.schedule_initial/1`.

**Stuck:** Oban job in `:executing` state with `attempted_at < now - (5 × check.interval_seconds)`. Detected via `Scheduler.stuck_executing_jobs(now)` where `now` is supplied by the caller (the reaper passes `DateTime.utc_now/0`; tests pass an explicit timestamp for determinism). Action: cancel that specific job, then `Scheduler.schedule_initial/1` for the check.

**Why these two:** They cover the realistic failure modes — chain broken (orphan) and worker process crashed mid-execution without Oban transitioning the job (stuck). Drift was explicitly out of scope.

**Orphan vs stuck — non-overlapping by construction:** `Scheduler.orphaned_checks/0` already counts `:executing` as a "pending" state. So a check with a stuck-executing job is NOT considered orphaned and won't be touched by the orphan path. Stuck-executing jobs are only recovered by the separate stuck path, which cancels the wedged job and reschedules. There is no double-recovery.

**Stuck threshold tradeoff:** `5 × interval_seconds` allows generous headroom over the worker's `@default_timeout_ms` (30s) for any check ≥ 30s interval (system minimum). For a 30s check this is 150s — comfortably above the HTTP timeout. For a 1-hour check it's 5 hours, which is fine because a job stuck for 5 hours on an hourly check has clearly failed.

### Decision: Reaper runs every 60 seconds via `Oban.Plugins.Cron`

```elixir
config :app, Oban,
  repo: GI.Repo,
  plugins: [{Oban.Plugins.Cron, crontab: [{"* * * * *", GI.Monitoring.Workers.Reaper}]}],
  queues: [...]
```

**Why:** Idiomatic for an Oban-based app. No new supervision tree to maintain. Recovery time bounded to ~60s, which is 2× the smallest legal check interval (30s). Faster cadence (e.g., 30s) would halve recovery time but double the DB query load for the orphan-detection query — not justified.

### Decision: Telemetry per recovery + PubSub per run

**Telemetry events:**

- `[:ff, :monitoring, :reaper, :run]` — emitted once per reaper invocation.
  - measurements: `%{duration_ms, recovered_count, orphan_count, stuck_count}`
  - metadata: `%{}`
- `[:ff, :monitoring, :reaper, :recovered]` — emitted once per recovered check.
  - measurements: `%{}`
  - metadata: `%{check_id, reason}` (reason ∈ `:orphaned | :stuck`)

**PubSub:**

- Topic: `"monitoring:reaper"` (global — reaper crosses projects)
- Event: `{:reaper_run_completed, %{count: integer, by_reason: %{orphaned: n, stuck: n}}}`
  - Emitted once per reaper run. Always emitted, even when count is 0, so subscribers can show "last reaper run was N seconds ago / 0 issues."

**Why this split:** Telemetry per-recovery is where metrics aggregate naturally (counters per reason). PubSub per-run is what dashboards consume — bounded chatter (one event/min) regardless of how many checks were recovered.

### Decision: Drop `:executing` from `CheckRunner` `unique` states (encode as requirement)

The unique constraint becomes:

```elixir
unique: [keys: [:check_id], states: [:available, :scheduled, :retryable]]
```

**Why:** The bug we just diagnosed. The executing job matched its own self-reschedule and the new insert was discarded. Already fixed in the working tree; this proposal encodes it as a spec requirement so future contributors do not regress the change.

## Risks

- **Reaper enqueues a duplicate if `unique` ever loosens further.** Mitigation: orphan detection requires `count = 0`, and `Scheduler.schedule_initial/1` still goes through `Oban.insert` which honours the unique constraint. Duplicate by construction is not possible.
- **Stuck threshold trips on a legitimately slow check.** With `5 × interval` and a 30s interval being the system minimum, the threshold is 150s — well above the 30s HTTP timeout. A run cannot legitimately exceed the timeout. Safe.
- **Always-emit PubSub creates noise.** One event per minute, lifetime of the application. Not material. Subscribers can ignore zero-count events.

## Open Questions

None — all sub-decisions resolved during exploration.
