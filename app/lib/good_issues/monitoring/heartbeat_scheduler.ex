defmodule GI.Monitoring.HeartbeatScheduler do
  @moduledoc """
  Oban job scheduling for heartbeat deadline detection.

  Manages the per-heartbeat deadline chain: scheduling, cancelling, and
  recovering deadline jobs. Each heartbeat gets its own Oban job that
  fires at the persisted `next_due_at` time.
  """

  import Ecto.Query

  alias GI.Monitoring.Heartbeat
  alias GI.Monitoring.Workers.HeartbeatDeadline
  alias GI.Repo

  @doc """
  Schedules a deadline job for the heartbeat based on its `next_due_at`.
  Returns the inserted Oban job or `:noop` if paused.
  """
  def schedule_deadline(%Heartbeat{paused: true}), do: :noop

  def schedule_deadline(%Heartbeat{next_due_at: nil}), do: :noop

  def schedule_deadline(%Heartbeat{} = heartbeat) do
    now = DateTime.utc_now(:second)
    delay = max(DateTime.diff(heartbeat.next_due_at, now, :second), 0)

    %{heartbeat_id: heartbeat.id, scheduled_for: DateTime.to_iso8601(heartbeat.next_due_at)}
    |> HeartbeatDeadline.new(schedule_in: delay)
    |> Oban.insert()
  end

  @doc """
  Cancels all pending/scheduled/retryable deadline jobs for a heartbeat.
  """
  def cancel_deadline(%Heartbeat{id: heartbeat_id}) do
    query =
      from(j in Oban.Job,
        where: j.queue == "heartbeats",
        where: j.state in ["available", "scheduled", "retryable"],
        where: fragment("?->>'heartbeat_id' = ?", j.args, ^heartbeat_id)
      )

    Oban.cancel_all_jobs(query)
    :ok
  end

  @doc """
  Returns active non-paused heartbeats that have no pending deadline job.
  """
  def orphaned_heartbeats do
    pending_states = ~w(available scheduled retryable executing)

    pending_ids_query =
      from(j in Oban.Job,
        where: j.queue == "heartbeats",
        where: j.state in ^pending_states,
        select: fragment("(?->>'heartbeat_id')::uuid", j.args)
      )

    from(h in Heartbeat,
      where: h.paused == false,
      where: not is_nil(h.next_due_at),
      where: h.id not in subquery(pending_ids_query)
    )
    |> Repo.all()
  end

  @doc """
  Re-enqueues orphaned heartbeats, emitting telemetry for each.
  Returns the number recovered.
  """
  def recover_orphaned_jobs do
    orphans = orphaned_heartbeats()

    Enum.each(orphans, fn heartbeat ->
      schedule_deadline(heartbeat)

      :telemetry.execute(
        [:ff, :monitoring, :heartbeat_reaper, :recovered],
        %{},
        %{heartbeat_id: heartbeat.id, reason: :orphaned}
      )
    end)

    length(orphans)
  end

  @doc """
  Returns Oban jobs stuck in `:executing` for heartbeats where
  `attempted_at < now - (5 * interval_seconds)`.
  """
  def stuck_executing_jobs(%DateTime{} = now) do
    from(j in Oban.Job,
      join: h in Heartbeat,
      on: fragment("(?->>'heartbeat_id')::uuid", j.args) == h.id,
      where: j.queue == "heartbeats",
      where: j.state == "executing",
      where: h.paused == false,
      where:
        j.attempted_at <
          fragment(
            "?::timestamp - make_interval(secs => ?::double precision * 5)",
            ^now,
            h.interval_seconds
          ),
      select: {j, h}
    )
    |> Repo.all()
  end

  @doc """
  Cancels a single stuck job with tenant isolation check.
  """
  def cancel_job(%Oban.Job{id: job_id}, %Heartbeat{id: heartbeat_id}) do
    query =
      from(j in Oban.Job,
        where: j.id == ^job_id,
        where: fragment("?->>'heartbeat_id' = ?", j.args, ^heartbeat_id)
      )

    Oban.cancel_all_jobs(query)
  end
end
