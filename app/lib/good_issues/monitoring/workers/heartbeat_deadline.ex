defmodule GI.Monitoring.Workers.HeartbeatDeadline do
  @moduledoc """
  Oban worker that fires when a heartbeat's deadline passes without a
  ping. Uses the hardened scheduling model from `harden-check-scheduling`:

  - Reschedule only fires on successful transaction (not in `after` block)
  - Unique states exclude `:executing` so self-rescheduling doesn't
    conflict with the in-flight job
  - `scheduled_for` in job args is validated against `heartbeat.next_due_at`
    to detect stale jobs that should no-op
  - Job ownership guard prevents double-apply from recovered stuck jobs

  ## Deadline logic

  When the job fires and its `scheduled_for` matches the heartbeat's
  current `next_due_at`, the worker:

  1. Locks the heartbeat row (FOR UPDATE)
  2. Verifies job ownership via `current_deadline_job_id`
  3. Increments `consecutive_failures`
  4. Clears `started_at` (stale start from a dead run)
  5. Advances `next_due_at` from the prior due time
  6. Evaluates the incident threshold
  """

  use Oban.Worker,
    queue: :heartbeats,
    max_attempts: 1,
    unique: [
      keys: [:heartbeat_id],
      states: [:available, :scheduled, :retryable]
    ]

  require Logger

  import Ecto.Query

  alias GI.Monitoring
  alias GI.Monitoring.{Heartbeat, HeartbeatIncidentLifecycle, HeartbeatScheduler}
  alias GI.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"heartbeat_id" => heartbeat_id} = args}) do
    scheduled_for = Map.get(args, "scheduled_for")

    case run_deadline(heartbeat_id, scheduled_for) do
      {:ok, _} ->
        reschedule_if_active(heartbeat_id)

      :ok ->
        reschedule_if_active(heartbeat_id)

      {:error, reason} ->
        Logger.warning("HeartbeatDeadline failed for #{heartbeat_id}: #{inspect(reason)}")
    end

    :ok
  end

  defp run_deadline(heartbeat_id, scheduled_for) do
    Repo.transaction(fn ->
      case lock_heartbeat(heartbeat_id) do
        nil ->
          :ok

        %Heartbeat{paused: true} ->
          :ok

        %Heartbeat{} = heartbeat ->
          if stale?(heartbeat, scheduled_for) do
            Logger.debug("HeartbeatDeadline stale for #{heartbeat_id}, skipping")
            :ok
          else
            apply_deadline(heartbeat)
          end
      end
    end)
  end

  defp lock_heartbeat(heartbeat_id) do
    from(h in Heartbeat, where: h.id == ^heartbeat_id, lock: "FOR UPDATE")
    |> Repo.one()
  end

  defp stale?(%Heartbeat{next_due_at: next_due_at}, scheduled_for)
       when is_binary(scheduled_for) do
    case DateTime.from_iso8601(scheduled_for) do
      {:ok, sf, _} ->
        # Stale if the heartbeat's current due time differs from what this job was scheduled for
        DateTime.truncate(next_due_at, :second) != DateTime.truncate(sf, :second)

      _ ->
        # Malformed scheduled_for — treat as stale to be safe
        Logger.warning("HeartbeatDeadline malformed scheduled_for: #{inspect(scheduled_for)}")
        true
    end
  end

  defp stale?(_heartbeat, _scheduled_for), do: false

  defp apply_deadline(%Heartbeat{} = heartbeat) do
    new_failures = heartbeat.consecutive_failures + 1

    # Advance next_due_at from the prior due time
    new_due_at =
      DateTime.add(
        heartbeat.next_due_at,
        heartbeat.interval_seconds + heartbeat.grace_seconds,
        :second
      )

    {:ok, updated} =
      Monitoring.update_heartbeat_runtime(heartbeat, %{
        consecutive_failures: new_failures,
        started_at: nil,
        next_due_at: new_due_at,
        status: if(new_failures >= heartbeat.failure_threshold, do: :down, else: heartbeat.status)
      })

    Monitoring.broadcast_heartbeat_updated(updated)

    if updated.status != heartbeat.status do
      Monitoring.broadcast_heartbeat_status_changed(updated)
    end

    if new_failures >= heartbeat.failure_threshold do
      HeartbeatIncidentLifecycle.create_or_reopen_incident(updated)
    end

    :ok
  end

  defp reschedule_if_active(heartbeat_id) do
    case Repo.get(Heartbeat, heartbeat_id) do
      nil -> :ok
      %Heartbeat{paused: true} -> :ok
      heartbeat -> HeartbeatScheduler.schedule_deadline(heartbeat)
    end
  end
end
