defmodule GI.Monitoring do
  @moduledoc """
  The Monitoring context.

  Manages uptime checks and their execution results. Checks are HTTP
  monitors scoped to a project; each check runs at its configured
  interval via a self-rescheduling Oban worker (see
  `GI.Monitoring.Workers.CheckRunner`). Failed checks auto-create
  incident issues through `GI.Monitoring.IncidentLifecycle`.
  """

  import Ecto.Query

  alias GI.Accounts.{Account, User}
  alias GI.Monitoring.{Check, CheckResult, Heartbeat, HeartbeatPing, Scheduler}
  alias GI.Monitoring.{AlertRuleEvaluator, HeartbeatIncidentLifecycle, HeartbeatScheduler}
  alias GI.Repo
  alias GI.Tracking.{Issue, Project}

  @default_per_page 20
  @max_per_page 100

  # ==========================================================================
  # PubSub
  # ==========================================================================

  @doc "Returns the PubSub topic for check events scoped to a project."
  def checks_topic(project_id) when is_binary(project_id) do
    "checks:project:#{project_id}"
  end

  defp broadcast_check_created(%Check{} = check) do
    Phoenix.PubSub.broadcast(
      GI.PubSub,
      checks_topic(check.project_id),
      {:check_created, check_payload(check)}
    )
  end

  defp broadcast_check_updated(%Check{} = check) do
    Phoenix.PubSub.broadcast(
      GI.PubSub,
      checks_topic(check.project_id),
      {:check_updated, check_payload(check)}
    )
  end

  defp broadcast_check_deleted(%Check{} = check) do
    Phoenix.PubSub.broadcast(
      GI.PubSub,
      checks_topic(check.project_id),
      {:check_deleted, %{id: check.id}}
    )
  end

  @doc false
  def broadcast_check_run_completed(%Check{} = check) do
    Phoenix.PubSub.broadcast(
      GI.PubSub,
      checks_topic(check.project_id),
      {:check_run_completed, check_payload(check)}
    )
  end

  @doc false
  def broadcast_check_result_created(%Check{} = check, %CheckResult{} = result) do
    Phoenix.PubSub.broadcast(
      GI.PubSub,
      checks_topic(check.project_id),
      {:check_result_created, check_result_payload(check, result)}
    )
  end

  defp check_result_payload(%Check{} = check, %CheckResult{} = result) do
    %{check_id: check.id, result: result}
  end

  defp check_payload(%Check{} = check) do
    %{
      id: check.id,
      name: check.name,
      url: check.url,
      method: check.method,
      status: check.status,
      paused: check.paused,
      interval_seconds: check.interval_seconds,
      last_checked_at: check.last_checked_at,
      consecutive_failures: check.consecutive_failures,
      failure_threshold: check.failure_threshold
    }
  end

  @doc """
  Returns the global PubSub topic for reaper events.

  **Internal-only** — this topic exposes system-wide operational state
  (recovery counts, run durations). It must not be subscribed to from
  end-user sockets or LiveViews without admin authorization.
  """
  def reaper_topic, do: "monitoring:reaper"

  @doc "Broadcasts a reaper run completion event."
  def broadcast_reaper_run_completed(payload) do
    Phoenix.PubSub.broadcast(
      GI.PubSub,
      reaper_topic(),
      {:reaper_run_completed, payload}
    )
  end

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
  Returns a map of check counts by status for a project:
  `%{up: n, down: n, unknown: n, paused: n}`.
  """
  def count_checks_by_status(%Account{} = account, project_id) do
    case fetch_project(account, project_id) do
      nil ->
        %{up: 0, down: 0, unknown: 0, paused: 0}

      %Project{id: pid} ->
        counts =
          from(c in Check,
            where: c.project_id == ^pid,
            group_by: [c.status, c.paused],
            select: {c.status, c.paused, count(c.id)}
          )
          |> Repo.all()

        Enum.reduce(counts, %{up: 0, down: 0, unknown: 0, paused: 0}, fn
          {_status, true, n}, acc -> Map.update!(acc, :paused, &(&1 + n))
          {:up, false, n}, acc -> Map.update!(acc, :up, &(&1 + n))
          {:down, false, n}, acc -> Map.update!(acc, :down, &(&1 + n))
          {:unknown, false, n}, acc -> Map.update!(acc, :unknown, &(&1 + n))
        end)
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
    |> tap_on_ok(&broadcast_check_created/1)
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
    |> tap_on_ok(&broadcast_check_updated/1)
  end

  @doc "Deletes a check and cancels any pending Oban jobs for it."
  def delete_check(%Check{} = check) do
    Scheduler.cancel_jobs(check)

    Repo.delete(check)
    |> tap_on_ok(fn _deleted -> broadcast_check_deleted(check) end)
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

        base_query =
          from(r in CheckResult, where: r.check_id == ^cid)
          |> maybe_filter_result_status(filters[:status] || filters["status"])

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

  defp classify_incident(issue, %Check{reopen_window_hours: window}, now) do
    GI.Monitoring.SharedIncidentLifecycle.classify_incident(issue, window, now)
  end

  # ==========================================================================
  # Heartbeats — CRUD
  # ==========================================================================

  @doc """
  Lists heartbeats for a project. Verifies the project belongs to the
  given account.
  """
  def list_heartbeats(%Account{} = account, project_id, filters \\ %{}) do
    case fetch_project(account, project_id) do
      nil ->
        %{heartbeats: [], page: 1, per_page: parse_per_page(filters), total: 0, total_pages: 1}

      %Project{id: pid} ->
        {page, per_page} = extract_pagination(filters)

        base_query = from(h in Heartbeat, where: h.project_id == ^pid)
        total = Repo.aggregate(base_query, :count)
        total_pages = max(ceil(total / per_page), 1)

        heartbeats =
          base_query
          |> order_by([h], asc: h.name)
          |> limit(^per_page)
          |> offset(^((page - 1) * per_page))
          |> Repo.all()

        %{
          heartbeats: heartbeats,
          page: page,
          per_page: per_page,
          total: total,
          total_pages: total_pages
        }
    end
  end

  @doc """
  Gets a single heartbeat scoped to account and project.
  Returns `nil` if not found or scope check fails.
  """
  def get_heartbeat(%Account{} = account, project_id, heartbeat_id) do
    cond do
      not valid_uuid?(project_id) -> nil
      not valid_uuid?(heartbeat_id) -> nil
      true -> do_get_heartbeat(account, project_id, heartbeat_id)
    end
  end

  defp do_get_heartbeat(account, project_id, heartbeat_id) do
    case fetch_project(account, project_id) do
      nil ->
        nil

      %Project{id: pid} ->
        Heartbeat
        |> where([h], h.id == ^heartbeat_id and h.project_id == ^pid)
        |> Repo.one()
    end
  end

  @doc "Bang variant of `get_heartbeat/3`."
  def get_heartbeat!(%Account{} = account, project_id, heartbeat_id) do
    case get_heartbeat(account, project_id, heartbeat_id) do
      nil -> raise Ecto.NoResultsError, queryable: Heartbeat
      heartbeat -> heartbeat
    end
  end

  @doc """
  Looks up a heartbeat by project_id and ping_token.
  Used by public ping endpoints. Returns `nil` on mismatch.
  """
  def get_heartbeat_by_token(project_id, token) do
    if valid_uuid?(project_id) and valid_ping_token?(token) do
      token_hash = Heartbeat.hash_token(token)

      Heartbeat
      |> where([h], h.project_id == ^project_id and h.ping_token_hash == ^token_hash)
      |> Repo.one()
    end
  end

  defp valid_ping_token?(token) when is_binary(token) do
    byte_size(token) == Heartbeat.token_length() and
      Regex.match?(~r/\A[A-Za-z0-9_-]+\z/, token)
  end

  defp valid_ping_token?(_), do: false

  @doc """
  Creates a heartbeat within a project. Generates a unique ping token,
  sets `next_due_at`, and schedules the first deadline unless paused.
  """
  def create_heartbeat(%Account{} = account, %User{id: user_id}, attrs) do
    project_id = attrs[:project_id] || attrs["project_id"]

    case fetch_project(account, project_id) do
      nil -> {:error, heartbeat_project_not_found_changeset(attrs)}
      %Project{id: pid} -> insert_heartbeat(pid, user_id, attrs)
    end
  end

  defp heartbeat_project_not_found_changeset(attrs) do
    %Heartbeat{}
    |> Heartbeat.create_changeset(Map.put(attrs, :ping_token, "x"))
    |> Ecto.Changeset.add_error(:project_id, "does not exist or belongs to another account")
  end

  defp insert_heartbeat(project_id, user_id, attrs, attempt \\ 1) do
    now = DateTime.utc_now(:second)
    token = Heartbeat.generate_token()

    attrs =
      attrs
      |> normalize_attrs()
      |> Map.put(:project_id, project_id)
      |> Map.put(:created_by_id, user_id)
      |> Map.put(:ping_token, token)

    paused = Map.get(attrs, :paused, false)

    interval = Map.get(attrs, :interval_seconds, 300)
    grace = Map.get(attrs, :grace_seconds, 0)

    attrs =
      if paused do
        attrs
      else
        Map.put(attrs, :next_due_at, DateTime.add(now, interval + grace, :second))
      end

    %Heartbeat{}
    |> Heartbeat.create_changeset(attrs)
    |> Repo.insert()
    |> tap_on_ok(&maybe_schedule_heartbeat_deadline/1)
  rescue
    e in Ecto.ConstraintError ->
      if e.constraint == "heartbeats_ping_token_hash_index" and attempt < 3 do
        insert_heartbeat(project_id, user_id, Map.delete(attrs, :ping_token), attempt + 1)
      else
        reraise e, __STACKTRACE__
      end
  end

  defp maybe_schedule_heartbeat_deadline(%Heartbeat{paused: true}), do: :noop

  defp maybe_schedule_heartbeat_deadline(%Heartbeat{} = hb),
    do: HeartbeatScheduler.schedule_deadline(hb)

  @doc """
  Updates a heartbeat. Manages deadline jobs on pause/resume and
  interval/grace changes.
  """
  def update_heartbeat(%Heartbeat{} = heartbeat, attrs) do
    was_paused? = heartbeat.paused

    heartbeat
    |> Heartbeat.update_changeset(attrs)
    |> Repo.update()
    |> tap_on_ok(fn updated ->
      cond do
        # Resuming from pause
        was_paused? and not updated.paused ->
          now = DateTime.utc_now(:second)
          new_due = DateTime.add(now, updated.interval_seconds + updated.grace_seconds, :second)
          {:ok, scheduled} = update_heartbeat_runtime(updated, %{next_due_at: new_due})
          HeartbeatScheduler.schedule_deadline(scheduled)

        # Pausing
        not was_paused? and updated.paused ->
          HeartbeatScheduler.cancel_deadline(updated)

        # Interval/grace changed while active
        not updated.paused and
            (updated.interval_seconds != heartbeat.interval_seconds or
               updated.grace_seconds != heartbeat.grace_seconds) ->
          HeartbeatScheduler.cancel_deadline(updated)
          now = DateTime.utc_now(:second)
          new_due = DateTime.add(now, updated.interval_seconds + updated.grace_seconds, :second)
          {:ok, scheduled} = update_heartbeat_runtime(updated, %{next_due_at: new_due})
          HeartbeatScheduler.schedule_deadline(scheduled)

        true ->
          :ok
      end
    end)
  end

  @doc """
  Deletes a heartbeat and cancels pending deadline jobs. Does NOT
  auto-archive any existing linked incident.
  """
  def delete_heartbeat(%Heartbeat{} = heartbeat) do
    HeartbeatScheduler.cancel_deadline(heartbeat)
    Repo.delete(heartbeat)
  end

  @doc """
  Updates runtime fields on a heartbeat (status, consecutive_failures,
  etc.). Used by workers and lifecycle — not exposed via the API.
  """
  def update_heartbeat_runtime(%Heartbeat{} = heartbeat, attrs) do
    heartbeat
    |> Heartbeat.runtime_changeset(attrs)
    |> Repo.update()
  end

  # ==========================================================================
  # Heartbeat Pings
  # ==========================================================================

  @doc """
  Lists pings for a heartbeat in reverse chronological order.
  """
  def list_heartbeat_pings(%Heartbeat{id: heartbeat_id}, filters \\ %{}) do
    {page, per_page} = extract_pagination(filters)

    base_query = from(p in HeartbeatPing, where: p.heartbeat_id == ^heartbeat_id)
    total = Repo.aggregate(base_query, :count)
    total_pages = max(ceil(total / per_page), 1)

    pings =
      base_query
      |> order_by([p], desc: p.pinged_at, desc: p.id)
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{
      pings: pings,
      page: page,
      per_page: per_page,
      total: total,
      total_pages: total_pages
    }
  end

  @doc """
  Receives a ping for a heartbeat. Runs inside a locked transaction that:
  1. Records the HeartbeatPing
  2. Mutates heartbeat state
  3. Performs incident lifecycle actions

  `kind` is one of `:ping`, `:start`, `:fail`.
  `attrs` may include `:payload`, `:exit_code`.
  """
  def receive_ping(%Heartbeat{} = heartbeat, kind, attrs \\ %{}) do
    result =
      Repo.transaction(fn ->
        # Lock the heartbeat row
        locked =
          from(h in Heartbeat, where: h.id == ^heartbeat.id, lock: "FOR UPDATE")
          |> Repo.one!()

        case kind do
          :start -> handle_start_ping(locked, attrs)
          :ping -> handle_success_ping(locked, attrs)
          :fail -> handle_fail_ping(locked, attrs)
        end
      end)

    case result do
      {:ok, {:ok, ping}} -> {:ok, ping}
      {:ok, {:error, _} = error} -> error
      {:error, _} = error -> error
    end
  end

  defp handle_start_ping(%Heartbeat{} = heartbeat, attrs) do
    now = DateTime.utc_now()
    payload = Map.get(attrs, :payload)

    with {:ok, ping} <-
           insert_heartbeat_ping(heartbeat, :start, %{payload: payload, pinged_at: now}),
         {:ok, _} <- update_heartbeat_runtime(heartbeat, %{started_at: now}) do
      {:ok, ping}
    end
  end

  defp handle_success_ping(%Heartbeat{} = heartbeat, attrs) do
    now = DateTime.utc_now()
    payload = Map.get(attrs, :payload)

    # Compute duration if started_at is set
    duration_ms =
      if heartbeat.started_at do
        DateTime.diff(now, heartbeat.started_at, :millisecond)
        |> max(0)
      end

    with {:ok, ping} <-
           insert_heartbeat_ping(heartbeat, :ping, %{
             payload: payload,
             duration_ms: duration_ms,
             pinged_at: now
           }) do
      # Evaluate alert rules
      eval_payload = AlertRuleEvaluator.inject_duration(payload, duration_ms)
      rule_result = AlertRuleEvaluator.evaluate(heartbeat.alert_rules, eval_payload)

      new_due_at =
        DateTime.add(now, heartbeat.interval_seconds + heartbeat.grace_seconds, :second)
        |> DateTime.truncate(:second)

      HeartbeatScheduler.cancel_deadline(heartbeat)

      case rule_result do
        :pass ->
          runtime_attrs = %{
            last_ping_at: DateTime.truncate(now, :second),
            started_at: nil,
            next_due_at: new_due_at,
            consecutive_failures: 0,
            status: :up
          }

          {:ok, updated} = update_heartbeat_runtime(heartbeat, runtime_attrs)
          HeartbeatScheduler.schedule_deadline(updated)

          if heartbeat.status == :down do
            HeartbeatIncidentLifecycle.handle_recovery(updated)
          end

          {:ok, ping}

        :fail ->
          new_failures = heartbeat.consecutive_failures + 1

          runtime_attrs = %{
            last_ping_at: DateTime.truncate(now, :second),
            started_at: nil,
            next_due_at: new_due_at,
            consecutive_failures: new_failures,
            status:
              if(new_failures >= heartbeat.failure_threshold, do: :down, else: heartbeat.status)
          }

          {:ok, updated} = update_heartbeat_runtime(heartbeat, runtime_attrs)
          HeartbeatScheduler.schedule_deadline(updated)

          if new_failures >= heartbeat.failure_threshold do
            HeartbeatIncidentLifecycle.create_or_reopen_incident(updated, ping)
          end

          {:ok, ping}
      end
    end
  end

  defp handle_fail_ping(%Heartbeat{} = heartbeat, attrs) do
    now = DateTime.utc_now()
    payload = Map.get(attrs, :payload)
    exit_code = Map.get(attrs, :exit_code)

    with {:ok, ping} <-
           insert_heartbeat_ping(heartbeat, :fail, %{
             payload: payload,
             exit_code: exit_code,
             pinged_at: now
           }) do
      new_failures = heartbeat.consecutive_failures + 1

      new_due_at =
        DateTime.add(now, heartbeat.interval_seconds + heartbeat.grace_seconds, :second)
        |> DateTime.truncate(:second)

      HeartbeatScheduler.cancel_deadline(heartbeat)

      runtime_attrs = %{
        started_at: nil,
        next_due_at: new_due_at,
        consecutive_failures: new_failures,
        status: if(new_failures >= heartbeat.failure_threshold, do: :down, else: heartbeat.status)
      }

      {:ok, updated} = update_heartbeat_runtime(heartbeat, runtime_attrs)
      HeartbeatScheduler.schedule_deadline(updated)

      if new_failures >= heartbeat.failure_threshold do
        HeartbeatIncidentLifecycle.create_or_reopen_incident(updated, ping)
      end

      {:ok, ping}
    end
  end

  defp insert_heartbeat_ping(%Heartbeat{id: heartbeat_id}, kind, attrs) do
    attrs =
      attrs
      |> Map.put(:kind, kind)
      |> Map.put(:heartbeat_id, heartbeat_id)

    %HeartbeatPing{}
    |> HeartbeatPing.create_changeset(attrs)
    |> Repo.insert()
  end

  # ==========================================================================
  # Helpers
  # ==========================================================================

  defp maybe_filter_result_status(query, nil), do: query
  defp maybe_filter_result_status(query, ""), do: query

  defp maybe_filter_result_status(query, status) when is_atom(status) do
    from(r in query, where: r.status == ^status)
  end

  defp maybe_filter_result_status(query, status) when is_binary(status) do
    case status do
      "up" -> maybe_filter_result_status(query, :up)
      "down" -> maybe_filter_result_status(query, :down)
      _ -> query
    end
  end

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
