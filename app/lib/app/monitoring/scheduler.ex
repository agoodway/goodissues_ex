defmodule FF.Monitoring.Scheduler do
  @moduledoc """
  Oban job scheduling for uptime checks.

  Wraps the `FF.Monitoring.Workers.CheckRunner` worker so the context,
  worker, and lifecycle modules don't need to know about Oban specifics.
  Scheduling is idempotent: the worker uses a `unique` constraint keyed
  on `:check_id` so duplicate enqueues collapse into a single pending
  job.
  """

  import Ecto.Query

  alias FF.Monitoring.Check
  alias FF.Monitoring.Workers.CheckRunner
  alias FF.Repo

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
  Re-enqueues any orphaned checks. Called from `FF.Application` after
  Oban boots.
  """
  def recover_orphaned_jobs do
    Enum.each(orphaned_checks(), &schedule_initial/1)
    :ok
  end

  defp insert_job(%Check{id: check_id}, opts) do
    %{check_id: check_id}
    |> CheckRunner.new(opts)
    |> Oban.insert()
  end
end
