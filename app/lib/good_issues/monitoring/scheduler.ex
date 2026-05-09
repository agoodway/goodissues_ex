defmodule GI.Monitoring.Scheduler do
  @moduledoc """
  Oban job scheduling for uptime checks.

  Wraps the `GI.Monitoring.Workers.CheckRunner` worker so the context,
  worker, and lifecycle modules don't need to know about Oban specifics.
  Scheduling is idempotent: the worker uses a `unique` constraint keyed
  on `:check_id` so duplicate enqueues collapse into a single pending
  job.
  """

  import Ecto.Query

  alias GI.Monitoring.Check
  alias GI.Monitoring.Workers.CheckRunner
  alias GI.Repo

  @doc """
  Enqueues the first job for a check, scheduled to run immediately.
  Returns the inserted (or pre-existing) Oban job, or `:noop` if the
  check is paused.
  """
  def schedule_initial(%Check{paused: true}), do: :noop

  def schedule_initial(%Check{} = check) do
    insert_job(check, schedule_in: 0)
  end

  @doc """
  Enqueues the next run for a check after `interval_seconds`.
  Returns the inserted Oban job, or `:noop` if the check is paused.
  """
  def schedule_next(%Check{paused: true}), do: :noop

  def schedule_next(%Check{interval_seconds: seconds} = check) when is_integer(seconds) do
    insert_job(check, schedule_in: seconds)
  end

  @doc """
  Cancels every pending or scheduled job for the given check.
  """
  def cancel_jobs(%Check{id: check_id}) do
    from(j in Oban.Job,
      where: j.queue == "checks",
      where: j.state in ["available", "scheduled", "retryable"],
      where: fragment("?->>'check_id' = ?", j.args, ^check_id)
    )
    |> Repo.update_all(set: [state: "cancelled"])

    :ok
  end

  @doc """
  Returns active checks (non-paused) that have no pending Oban job.
  Used at application startup to recover from crashes / deploys.
  """
  def orphaned_checks do
    pending_states = ~w(available scheduled retryable executing)

    pending_check_ids_query =
      from(j in Oban.Job,
        where: j.queue == "checks",
        where: j.state in ^pending_states,
        select: fragment("(?->>'check_id')::uuid", j.args)
      )

    from(c in Check,
      where: c.paused == false,
      where: c.id not in subquery(pending_check_ids_query)
    )
    |> Repo.all()
  end

  @doc """
  Re-enqueues any orphaned checks, emitting a `:recovered` telemetry
  event for each one. Called from `GI.Application` after Oban boots
  and from the Reaper worker.

  Returns the number of orphans recovered.
  """
  def recover_orphaned_jobs do
    orphans = orphaned_checks()

    Enum.each(orphans, fn check ->
      schedule_initial(check)

      :telemetry.execute(
        [:ff, :monitoring, :reaper, :recovered],
        %{},
        %{check_id: check.id, reason: :orphaned}
      )
    end)

    length(orphans)
  end

  @doc """
  Returns Oban jobs stuck in `:executing` state for non-paused checks
  where `attempted_at < now - (5 * check.interval_seconds)`.

  Each result is a `{job, check}` tuple so the caller can act in one pass.
  The explicit `now` argument supports test determinism.
  """
  def stuck_executing_jobs(%DateTime{} = now) do
    from(j in Oban.Job,
      join: c in Check,
      on: fragment("(?->>'check_id')::uuid", j.args) == c.id,
      where: j.queue == "checks",
      where: j.state == "executing",
      where: c.paused == false,
      where:
        j.attempted_at <
          fragment(
            "?::timestamp - make_interval(secs => ?::double precision * 5)",
            ^now,
            c.interval_seconds
          ),
      select: {j, c}
    )
    |> Repo.all()
  end

  @doc """
  Cancels a single Oban job, verifying it belongs to the expected check
  for tenant isolation. Returns `{:ok, n}` where `n` is the number of
  rows updated (0 or 1).
  """
  def cancel_job(%Oban.Job{id: job_id}, %Check{id: check_id}) do
    {n, _} =
      from(j in Oban.Job,
        where: j.id == ^job_id,
        where: fragment("?->>'check_id' = ?", j.args, ^check_id)
      )
      |> Repo.update_all(set: [state: "cancelled"])

    {:ok, n}
  end

  defp insert_job(%Check{id: check_id}, opts) do
    %{check_id: check_id}
    |> CheckRunner.new(opts)
    |> Oban.insert()
  end
end
