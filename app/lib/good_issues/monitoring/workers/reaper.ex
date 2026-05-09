defmodule GI.Monitoring.Workers.Reaper do
  @moduledoc """
  Periodic Oban worker that detects and recovers broken check chains.

  Runs every 60 seconds via `Oban.Plugins.Cron`. Recovers two failure modes:

  1. **Orphaned checks** — non-paused checks with zero pending/executing Oban
     jobs. Recovered by calling `Scheduler.recover_orphaned_jobs/0`.

  2. **Stuck executing jobs** — Oban jobs stuck in `:executing` state longer
     than `5 × check.interval_seconds`. Recovered by cancelling the stuck job
     and re-scheduling via `Scheduler.schedule_initial/1`.

  ## Race with CheckRunner

  When the reaper cancels a stuck job, the BEAM process may still be running.
  The reaper then calls `schedule_initial`, which succeeds because the Oban
  unique constraint on CheckRunner excludes `:executing` state. The old
  runner's stale completion is safe because CheckRunner verifies its
  `current_job_id` claim before writing results — see `CheckRunner` moduledoc.

  ## Telemetry Events

  * `[:ff, :monitoring, :reaper, :run]`
    - measurements: `%{duration_ms: integer, recovered_count: integer, orphan_count: integer, stuck_count: integer}`
    - metadata: `%{}`
    - Emitted once per reaper invocation.

  * `[:ff, :monitoring, :reaper, :recovered]`
    - measurements: `%{}`
    - metadata: `%{check_id: binary, reason: :orphaned | :stuck}`
    - Emitted once per recovered check.

  ## PubSub

  * Topic: `"monitoring:reaper"` (via `Monitoring.reaper_topic/0`)
    **Internal-only** — must not be exposed to end-user sockets or LiveViews
    without admin authorization, as it reveals system-wide operational state.
  * Event: `{:reaper_run_completed, %{count: integer, by_reason: %{orphaned: integer, stuck: integer}}}`
  * Emitted every run, even when count is 0.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 1,
    unique: [period: 55, states: [:available, :executing, :scheduled]]

  alias GI.Monitoring
  alias GI.Monitoring.Scheduler

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    start_time = System.monotonic_time(:millisecond)

    orphan_count = recover_orphans()
    stuck_count = recover_stuck()

    duration_ms = max(System.monotonic_time(:millisecond) - start_time, 0)
    recovered_count = orphan_count + stuck_count

    :telemetry.execute(
      [:ff, :monitoring, :reaper, :run],
      %{
        duration_ms: duration_ms,
        recovered_count: recovered_count,
        orphan_count: orphan_count,
        stuck_count: stuck_count
      },
      %{}
    )

    Monitoring.broadcast_reaper_run_completed(%{
      count: recovered_count,
      by_reason: %{orphaned: orphan_count, stuck: stuck_count}
    })

    :ok
  end

  defp recover_orphans do
    Scheduler.recover_orphaned_jobs()
  end

  defp recover_stuck do
    now = DateTime.utc_now(:second)
    stuck = Scheduler.stuck_executing_jobs(now)

    Enum.each(stuck, fn {job, check} ->
      Scheduler.cancel_job(job, check)
      Scheduler.schedule_initial(check)

      :telemetry.execute(
        [:ff, :monitoring, :reaper, :recovered],
        %{},
        %{check_id: check.id, reason: :stuck}
      )
    end)

    length(stuck)
  end
end
