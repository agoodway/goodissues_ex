# Inspector Explain — harden-check-scheduling

## One-Sentence Summary

Make the uptime check scheduling chain crash-proof and self-healing so a monitoring system never silently stops monitoring.

## The Problem

GoodIssues's uptime checks work as a **self-rescheduling Oban job chain**: each `CheckRunner` job runs a check, records the result, then enqueues the next job N seconds from now. This is a clean pattern, but it has a fatal fragility — if anything breaks the chain, monitoring stops silently until the next application restart.

Two concrete failure modes were identified:

```
FAILURE MODE 1: Oban unique constraint swallowed the reschedule
================================================================

     Job A (executing)
         │
         ├── run check, record result...
         │
         └── schedule_next(check)
                 │
                 ▼
          Oban.insert(%{check_id: "abc"})
                 │
                 ├── unique constraint checks [:available, :scheduled,
                 │   :retryable, :executing]
                 │            ▲
                 │            │
                 │   Job A itself matches ── `:executing` was in the list!
                 │
                 └── conflict?: true ── insert silently skipped
                                        chain DEAD


FAILURE MODE 2: Exception between result and reschedule
=======================================================

     Job A (executing)
         │
         ├── create_check_result(...)     ✓ saved to DB
         │
         ├── broadcast_check_result(...)  ✗ RAISES (PubSub crash, etc.)
         │         │
         │         └── Exception propagates up
         │
         └── schedule_next(check)         ← NEVER REACHED
                                            chain DEAD
```

In both cases, the check simply stops running. No error shows in the UI. Users assume monitoring is active while it isn't.

## The Fix: Three Layers of Defense

This change builds defense in depth with three independent mechanisms:

```
┌─────────────────────────────────────────────────────────┐
│                    DEFENSE IN DEPTH                      │
│                                                          │
│   Layer 1: try/after in perform/1                        │
│   ├── Reschedule runs NO MATTER WHAT happens in run()    │
│   └── Prevents chain breaks from exceptions              │
│                                                          │
│   Layer 2: Unique constraint fix                         │
│   ├── Drop :executing from unique states                 │
│   └── Prevents chain breaks from self-match              │
│                                                          │
│   Layer 3: Periodic Reaper (every 60s)                   │
│   ├── Catches anything Layers 1-2 miss                   │
│   ├── Recovers orphans (no pending job at all)            │
│   └── Recovers stuck jobs (executing too long)            │
│                                                          │
│   Existing: Boot-time recovery (unchanged)               │
│   └── Scheduler.recover_orphaned_jobs/0 at app start     │
└─────────────────────────────────────────────────────────┘
```

### Layer 1: Unconditional Reschedule via `try/after`

The `perform/1` function is restructured so the reschedule cannot be skipped:

```
BEFORE                              AFTER
──────                              ─────

def perform(job) do                 def perform(job) do
  case get_check(id) do               case get_check(id) do
    nil    -> :ok                        nil    -> :ok       ← gone, skip
    paused -> :ok                        paused -> :ok       ← paused, skip
    check  -> run(check)                 check  ->
  end                                      try do
end                                          run(check)     ← do the work
                                           after
defp run(check) do                           reschedule_if_active(id)
  # ... record result ...                  end
  # ... apply outcome ...               end
  # ... incident lifecycle ...         end
  Scheduler.schedule_next(check)
  :ok                                defp reschedule_if_active(id) do
end                                    case Repo.get(Check, id) do
                                         nil              -> :ok
                                         %{paused: true}  -> :ok
                                         check            -> Scheduler.schedule_next(check)
                                       end
                                     end
```

The `after` block runs whether `run/1` succeeds, raises, or throws. The re-fetch in `reschedule_if_active/1` ensures we don't reschedule a check that was deleted or paused during execution.

### Layer 2: Unique Constraint Fix (Already Applied)

This was already fixed in the working tree but is encoded as a spec requirement so future contributors don't regress it:

```
BEFORE: unique: [keys: [:check_id], states: [:available, :scheduled, :retryable, :executing]]
                                                                                  ^^^^^^^^^^
                                                                                  BUG: matches self

AFTER:  unique: [keys: [:check_id], states: [:available, :scheduled, :retryable]]
                                                                                  
                                                                                  :executing removed
```

### Layer 3: The Reaper

A new Oban worker that runs every 60 seconds as a safety net:

```
┌──────────────────────────────────────────────────────────────┐
│                GI.Monitoring.Workers.Reaper                   │
│                Runs every 60s via Oban.Plugins.Cron           │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│   1. Find ORPHANS                                            │
│      ┌────────────────────────────────────┐                  │
│      │ SELECT checks WHERE paused = false │                  │
│      │ AND no Oban jobs in                │                  │
│      │ [available, scheduled, retryable,  │                  │
│      │  executing]                        │                  │
│      └──────────────┬─────────────────────┘                  │
│                     │                                        │
│                     ▼                                        │
│          Scheduler.schedule_initial(check)                    │
│          Emit telemetry (reason: :orphaned)                   │
│                                                              │
│   2. Find STUCK jobs                                         │
│      ┌────────────────────────────────────┐                  │
│      │ SELECT oban_jobs WHERE             │                  │
│      │   state = :executing               │                  │
│      │   AND attempted_at < now -         │                  │
│      │       (5 * check.interval_seconds) │                  │
│      └──────────────┬─────────────────────┘                  │
│                     │                                        │
│                     ▼                                        │
│          Scheduler.cancel_job(stuck_job)                      │
│          Scheduler.schedule_initial(check)                    │
│          Emit telemetry (reason: :stuck)                      │
│                                                              │
│   3. Emit summary                                            │
│      Telemetry: [:ff, :monitoring, :reaper, :run]            │
│      PubSub:    {:reaper_run_completed, %{count, by_reason}} │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

**Why two categories?**

- **Orphans** = check has no job at all (chain broke completely)
- **Stuck** = job exists but is wedged in `:executing` (worker process died without Oban noticing)

These are non-overlapping by design: `orphaned_checks/0` counts `:executing` as "has a job", so a stuck check won't be double-recovered by both paths.

**Stuck threshold**: `5 * interval_seconds`. For a 30s check (minimum), that's 150s — well above the 30s HTTP timeout. For an hourly check, it's 5 hours. A job stuck that long has clearly failed.

## What Gets Added/Changed

```
MODULES CHANGED                          WHAT CHANGES
───────────────                          ────────────
GI.Monitoring.Workers.CheckRunner        perform/1 → try/after shape
                                         run/1 loses its schedule_next call

GI.Monitoring.Scheduler                  + stuck_executing_jobs/1 (new query)
                                         + cancel_job/1 (cancel single job)
                                         orphaned_checks/0, recover_orphaned_jobs/0
                                           unchanged — reused as-is

GI.Monitoring.Workers.Reaper             NEW — Oban worker, queue: :default
                                         Queries orphans + stuck, recovers,
                                         emits telemetry + PubSub

GI.Monitoring                            + reaper_topic/0
                                         + broadcast_reaper_run_completed/1

config/config.exs                        + Oban.Plugins.Cron with reaper schedule
config/test.exs                          + plugins: [] override
```

## Observability

```
TELEMETRY EVENTS                          WHEN EMITTED
────────────────                          ────────────
[:ff, :monitoring, :reaper, :run]         Every 60s (always, even if 0 recovered)
  measurements: duration_ms,              
    recovered_count, orphan_count,        
    stuck_count                           

[:ff, :monitoring, :reaper, :recovered]   Per recovered check
  metadata: check_id, reason              
    (reason: :orphaned | :stuck)          


PUBSUB EVENT                              TOPIC
────────────                              ─────
{:reaper_run_completed,                   "monitoring:reaper" (global)
 %{count: n, by_reason: %{               Emitted every run, even when count=0
   orphaned: n, stuck: n}}}              
```

The always-emit design lets dashboards show "last reaper run: 12s ago, 0 issues" — confirming the reaper itself is alive.

## Timeline of a Failure (Before vs After)

```
BEFORE: Chain breaks → monitoring stops → nobody notices → hours/days pass
═══════════════════════════════════════════════════════════════════════════

  t=0    CheckRunner runs, raises during broadcast
  t=0    schedule_next never called ── chain dead
  t=???  Next deploy restarts the app
  t=???  recover_orphaned_jobs picks it up
         Gap: could be hours or days


AFTER: Chain breaks → recovered within 60 seconds
═════════════════════════════════════════════════

  t=0    CheckRunner runs, raises during broadcast
  t=0    after clause calls reschedule_if_active ── chain restored (Layer 1)

  If Layer 1 also fails somehow:
  t=60   Reaper detects orphaned check ── chain restored (Layer 3)
  t=60   Telemetry + PubSub fire so operators see recovery happened
```

## Scope Boundaries

- **No public API changes** — this is purely internal reliability work
- **No interval drift detection** — if a user changes `interval_seconds` while a job is scheduled with the old value, it self-corrects on the next natural run
- **No watchdog for the reaper** — if `Oban.Plugins.Cron` dies, external monitoring (not GoodIssues) must catch that
- **Boot-time recovery unchanged** — `Scheduler.recover_orphaned_jobs/0` still runs at app start; the reaper is additive
