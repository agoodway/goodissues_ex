defmodule FF.Monitoring do
  @moduledoc """
  The Monitoring context.

  Manages uptime checks and their execution results. Checks are HTTP
  monitors scoped to a project; each check runs at its configured
  interval via a self-rescheduling Oban worker (see
  `FF.Monitoring.Workers.CheckRunner`). Failed checks auto-create
  incident issues through `FF.Monitoring.IncidentLifecycle`.
  """

  import Ecto.Query

  alias FF.Accounts.{Account, User}
  alias FF.Monitoring.{Check, CheckResult, Scheduler}
  alias FF.Repo
  alias FF.Tracking.{Issue, Project}

  @default_per_page 20
  @max_per_page 100

  # ==========================================================================
  # Checks — CRUD
  # ==========================================================================

  @doc """
  Lists checks for a project. Verifies the project belongs to the given
  account; returns `[]` when the project is not visible to the account.
  """
  def list_checks(%Account{} = account, project_id, filters \\ %{}) do
    case fetch_project(account, project_id) do
      nil ->
        %{checks: [], page: 1, per_page: parse_per_page(filters), total: 0, total_pages: 1}

      %Project{id: pid} ->
        {page, per_page} = extract_pagination(filters)

        base_query = from(c in Check, where: c.project_id == ^pid)
        total = Repo.aggregate(base_query, :count)
        total_pages = max(ceil(total / per_page), 1)

        checks =
          base_query
          |> order_by([c], asc: c.name)
          |> limit(^per_page)
          |> offset(^((page - 1) * per_page))
          |> Repo.all()

        %{
          checks: checks,
          page: page,
          per_page: per_page,
          total: total,
          total_pages: total_pages
        }
    end
  end

  @doc """
  Gets a single check scoped to the given account and project.
  Returns `nil` if the check, project, or scope check fails.
  """
  def get_check(%Account{} = account, project_id, check_id) do
    cond do
      not valid_uuid?(project_id) -> nil
      not valid_uuid?(check_id) -> nil
      true -> do_get_check(account, project_id, check_id)
    end
  end

  defp do_get_check(account, project_id, check_id) do
    case fetch_project(account, project_id) do
      nil ->
        nil

      %Project{id: pid} ->
        Check
        |> where([c], c.id == ^check_id and c.project_id == ^pid)
        |> Repo.one()
    end
  end

  @doc """
  Bang variant of `get_check/3`. Raises `Ecto.NoResultsError` if missing.
  """
  def get_check!(%Account{} = account, project_id, check_id) do
    case get_check(account, project_id, check_id) do
      nil -> raise Ecto.NoResultsError, queryable: Check
      check -> check
    end
  end

  @doc """
  Creates a check within a project for the given account.

  On success, schedules the first Oban job unless the check is paused.
  """
  def create_check(%Account{} = account, %User{id: user_id}, attrs) do
    project_id = attrs[:project_id] || attrs["project_id"]

    case fetch_project(account, project_id) do
      nil -> {:error, project_not_found_changeset(attrs)}
      %Project{id: pid} -> insert_check(pid, user_id, attrs)
    end
  end

  defp project_not_found_changeset(attrs) do
    %Check{}
    |> Check.create_changeset(attrs)
    |> Ecto.Changeset.add_error(:project_id, "does not exist or belongs to another account")
  end

  defp insert_check(project_id, user_id, attrs) do
    attrs =
      attrs
      |> normalize_attrs()
      |> Map.put(:project_id, project_id)
      |> Map.put(:created_by_id, user_id)

    %Check{}
    |> Check.create_changeset(attrs)
    |> Repo.insert()
    |> tap_on_ok(&maybe_schedule_initial/1)
  end

  defp maybe_schedule_initial(%Check{paused: true}), do: :noop
  defp maybe_schedule_initial(%Check{} = check), do: Scheduler.schedule_initial(check)

  @doc """
  Updates a check.

  If the update transitions the check from paused to unpaused, the
  worker is rescheduled. If the check becomes paused, the next run is
  cancelled by the worker itself when it observes the paused state.
  """
  def update_check(%Check{} = check, attrs) do
    was_paused? = check.paused

    check
    |> Check.update_changeset(attrs)
    |> Repo.update()
    |> tap_on_ok(fn updated ->
      if was_paused? and not updated.paused do
        Scheduler.schedule_initial(updated)
      end
    end)
  end

  @doc "Deletes a check and cancels any pending Oban jobs for it."
  def delete_check(%Check{} = check) do
    Scheduler.cancel_jobs(check)
    Repo.delete(check)
  end

  @doc "Returns a changeset for a check (used by tests / forms)."
  def change_check(%Check{} = check, attrs \\ %{}) do
    if check.id,
      do: Check.update_changeset(check, attrs),
      else: Check.create_changeset(check, attrs)
  end

  @doc """
  Updates only the runtime fields on a check (status, consecutive_failures,
  last_checked_at, current_issue_id). Used by the worker and incident
  lifecycle — not exposed via the public API.
  """
  def update_runtime_fields(%Check{} = check, attrs) do
    check
    |> Check.runtime_changeset(attrs)
    |> Repo.update()
  end

  # ==========================================================================
  # Check Results
  # ==========================================================================

  @doc """
  Lists results for a check, scoped to the given account/project.
  Reverse chronological. Returns paginated envelope or `nil` when the
  check is not visible.
  """
  def list_check_results(%Account{} = account, project_id, check_id, filters \\ %{}) do
    case get_check(account, project_id, check_id) do
      nil ->
        nil

      %Check{id: cid} ->
        {page, per_page} = extract_pagination(filters)

        base_query = from(r in CheckResult, where: r.check_id == ^cid)
        total = Repo.aggregate(base_query, :count)
        total_pages = max(ceil(total / per_page), 1)

        results =
          base_query
          |> order_by([r], desc: r.checked_at, desc: r.id)
          |> limit(^per_page)
          |> offset(^((page - 1) * per_page))
          |> Repo.all()

        %{
          results: results,
          page: page,
          per_page: per_page,
          total: total,
          total_pages: total_pages
        }
    end
  end

  @doc """
  Internal: records a single check_result. Used by the worker.
  """
  def create_check_result(%Check{id: check_id}, attrs) do
    attrs =
      attrs
      |> normalize_attrs()
      |> Map.put_new(:checked_at, DateTime.utc_now(:second))
      |> Map.put(:check_id, check_id)

    %CheckResult{}
    |> CheckResult.create_changeset(attrs)
    |> Repo.insert()
  end

  # ==========================================================================
  # Incident Lookup
  # ==========================================================================

  @doc """
  Finds an existing incident issue for a check.

  Returns:

    * `{:open, issue}` — there is an open (status :new or :in_progress)
      incident issue for this check
    * `{:reopen, issue}` — there is an archived incident issue for this
      check that was archived within `reopen_window_hours`
    * `:none` — no incident to use; a new issue should be created
  """
  def find_incident_issue(%Check{} = check, opts \\ []) do
    now = Keyword.get(opts, :now, DateTime.utc_now(:second))

    with %Issue{} = issue <- current_or_recent_incident(check) do
      classify_incident(issue, check, now)
    else
      _ -> :none
    end
  end

  defp current_or_recent_incident(%Check{current_issue_id: nil} = check) do
    most_recent_result_issue(check)
  end

  defp current_or_recent_incident(%Check{current_issue_id: issue_id}) do
    Repo.get(Issue, issue_id)
  end

  defp most_recent_result_issue(%Check{id: check_id}) do
    from(r in CheckResult,
      where: r.check_id == ^check_id and not is_nil(r.issue_id),
      order_by: [desc: r.checked_at, desc: r.id],
      limit: 1,
      select: r.issue_id
    )
    |> Repo.one()
    |> case do
      nil -> nil
      issue_id -> Repo.get(Issue, issue_id)
    end
  end

  defp classify_incident(%Issue{status: status} = issue, _check, _now)
       when status in [:new, :in_progress] do
    {:open, issue}
  end

  defp classify_incident(
         %Issue{status: :archived, archived_at: %DateTime{} = archived_at} = issue,
         %Check{reopen_window_hours: window},
         now
       ) do
    cutoff = DateTime.add(now, -window * 3600, :second)

    if DateTime.compare(archived_at, cutoff) != :lt do
      {:reopen, issue}
    else
      :none
    end
  end

  defp classify_incident(_issue, _check, _now), do: :none

  # ==========================================================================
  # Helpers
  # ==========================================================================

  defp fetch_project(_account, nil), do: nil

  defp fetch_project(%Account{id: account_id}, project_id) do
    if valid_uuid?(project_id) do
      Repo.get_by(Project, id: project_id, account_id: account_id)
    end
  end

  defp valid_uuid?(string) when is_binary(string) do
    case Ecto.UUID.dump(string) do
      {:ok, _} -> true
      :error -> false
    end
  end

  defp valid_uuid?(_), do: false

  defp extract_pagination(filters) do
    page = parse_positive_int(filters[:page] || filters["page"], 1)
    per_page = parse_per_page(filters)
    {page, per_page}
  end

  defp parse_per_page(filters) do
    parse_positive_int(filters[:per_page] || filters["per_page"], @default_per_page)
    |> min(@max_per_page)
  end

  defp parse_positive_int(value, _default) when is_integer(value) and value > 0, do: value

  defp parse_positive_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> int
      _ -> default
    end
  end

  defp parse_positive_int(_, default), do: default

  defp normalize_attrs(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {k, v} when is_binary(k) ->
        {String.to_existing_atom(k), v}

      {k, v} ->
        {k, v}
    end)
  rescue
    ArgumentError -> attrs
  end

  defp normalize_attrs(other), do: other

  defp tap_on_ok({:ok, value} = result, fun) do
    fun.(value)
    result
  end

  defp tap_on_ok(other, _fun), do: other
end
