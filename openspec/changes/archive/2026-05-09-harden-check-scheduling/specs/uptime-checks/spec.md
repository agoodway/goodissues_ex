## ADDED Requirements

### Requirement: Worker self-reschedule is unconditional

The `CheckRunner` worker SHALL enqueue the next run for an active (non-paused) check whenever `perform/1` returns, regardless of whether the body of the run succeeded or raised, provided the check still exists.

#### Scenario: Successful run reschedules next

- **WHEN** `CheckRunner.perform/1` runs to completion without raising
- **THEN** a new Oban job MUST be inserted for the same check via `Scheduler.schedule_next/1`

#### Scenario: Raised exception still reschedules next

- **WHEN** `CheckRunner.perform/1` raises during the body of the run (for example, a DB error during `create_check_result` or a PubSub crash)
- **THEN** a new Oban job MUST still be inserted for the same check before the worker returns

#### Scenario: Deleted check does not reschedule

- **WHEN** the check has been deleted before or during `perform/1`
- **THEN** no successor job is enqueued

#### Scenario: Paused check does not reschedule

- **WHEN** the check is paused at the time `perform/1` reaches its reschedule step
- **THEN** no successor job is enqueued

### Requirement: Worker unique constraint excludes executing state

The `CheckRunner` worker's Oban `unique` constraint SHALL match jobs only in `:available`, `:scheduled`, and `:retryable` states. The `:executing` state MUST NOT be included, so that a self-reschedule from inside `perform/1` is not treated as a conflict with the in-flight job.

#### Scenario: Self-reschedule from within perform inserts a new job

- **WHEN** `Scheduler.schedule_next/1` is called for a check while another job for that check is currently in `:executing` state
- **THEN** Oban MUST insert a new scheduled job (not return `conflict?: true` against the executing job)

### Requirement: Periodic reaper recovers broken scheduling chains

The system SHALL run `GI.Monitoring.Workers.Reaper` once per minute via `Oban.Plugins.Cron` to detect and recover non-paused checks whose scheduling chain has broken.

#### Scenario: Reaper recovers an orphaned check

- **WHEN** a non-paused check has zero Oban jobs in `[:available, :scheduled, :retryable, :executing]`
- **AND** the reaper runs
- **THEN** the reaper MUST call `Scheduler.schedule_initial/1` for that check
- **AND** a new scheduled job MUST exist for that check

#### Scenario: Reaper recovers a stuck-executing job

- **WHEN** an Oban job is in `:executing` state with `attempted_at < now - (5 × interval_seconds)` for its check
- **AND** the reaper runs
- **THEN** the reaper MUST cancel that specific job
- **AND** call `Scheduler.schedule_initial/1` for the check

#### Scenario: Reaper enqueues nothing when no checks need recovery

- **WHEN** the reaper runs and finds no orphans and no stuck jobs
- **THEN** the reaper MUST NOT enqueue any new jobs

(Observability events are emitted regardless — see the "Reaper activity is observable" requirement below for the always-emit guarantees.)

### Requirement: Reaper activity is observable via telemetry and PubSub

The reaper SHALL emit telemetry events for every run and every recovered check, and SHALL broadcast a PubSub event summarising each run on the `"monitoring:reaper"` topic.

#### Scenario: Per-run telemetry event

- **WHEN** the reaper finishes a run
- **THEN** a `[:ff, :monitoring, :reaper, :run]` telemetry event MUST be emitted
- **AND** the measurements MUST include `:duration_ms`, `:recovered_count`, `:orphan_count`, `:stuck_count`

#### Scenario: Per-recovery telemetry event

- **WHEN** the reaper recovers a check (orphan or stuck)
- **THEN** a `[:ff, :monitoring, :reaper, :recovered]` telemetry event MUST be emitted
- **AND** the metadata MUST include the recovered `:check_id` and a `:reason` of `:orphaned` or `:stuck`

#### Scenario: Per-run PubSub broadcast

- **WHEN** the reaper finishes a run
- **THEN** the system MUST broadcast `{:reaper_run_completed, payload}` on the `"monitoring:reaper"` PubSub topic
- **AND** the payload MUST include `:count` (total recovered) and `:by_reason` (a map keyed by `:orphaned` and `:stuck`)
- **AND** the broadcast MUST occur even when `count` is zero
