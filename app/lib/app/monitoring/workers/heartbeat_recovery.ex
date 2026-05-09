defmodule FF.Monitoring.Workers.HeartbeatRecovery do
  @moduledoc """
  Periodic Oban worker that recovers orphaned and stuck heartbeat
  deadline jobs. Runs on the `:maintenance` queue alongside the check
  Reaper but operates only on the `:heartbeats` queue.

  Recovery logic:

  - **Orphans**: Active non-paused heartbeats with `next_due_at` set
    but no pending deadline job
  - **Stuck**: Deadline jobs stuck in `:executing` for longer than
    `5 * interval_seconds`
  - **Overdue**: Heartbeats whose `next_due_at` is in the past get
    their deadline scheduled immediately at `now`
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 1,
    unique: [period: 55, states: [:available, :executing, :scheduled]]

  require Logger

  alias FF.Monitoring.HeartbeatScheduler

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    now = DateTime.utc_now(:second)

    orphan_count = HeartbeatScheduler.recover_orphaned_jobs()
    stuck_count = recover_stuck(now)

    :telemetry.execute(
      [:ff, :monitoring, :heartbeat_reaper, :run],
      %{orphan_count: orphan_count, stuck_count: stuck_count},
      %{}
    )

    :ok
  end

  defp recover_stuck(now) do
    stuck = HeartbeatScheduler.stuck_executing_jobs(now)

    Enum.each(stuck, fn {job, heartbeat} ->
      HeartbeatScheduler.cancel_job(job, heartbeat)
      HeartbeatScheduler.schedule_deadline(heartbeat)

      :telemetry.execute(
        [:ff, :monitoring, :heartbeat_reaper, :recovered],
        %{},
        %{heartbeat_id: heartbeat.id, reason: :stuck}
      )
    end)

    length(stuck)
  end
end
