defmodule GI.Monitoring.IncidentLifecycle do
  @moduledoc """
  Auto-creates, reopens, and archives incident issues based on check
  state transitions.

  Called from `GI.Monitoring.Workers.CheckRunner` after each check
  execution. Uses `GI.Accounts.get_or_create_bot_user!/1` so bot-authored
  issues never consume a real user seat.

  Delegates to `GI.Tracking.report_incident/5` and
  `GI.Tracking.resolve_incident/2` for incident lifecycle management.
  """

  alias GI.Accounts
  alias GI.Accounts.Account
  alias GI.Monitoring
  alias GI.Monitoring.{Check, CheckResult}
  alias GI.Repo
  alias GI.Tracking
  alias GI.Tracking.{Issue, Project}

  @doc """
  Called when a check has crossed `failure_threshold`. Creates a new
  incident, reopens a recently archived one, or adds an occurrence
  if an open incident already exists.

  Pass the account explicitly to avoid an extra lookup; it must be the
  account that owns the check's project.
  """
  def create_or_reopen_incident(%Account{} = account, %Check{} = check, %CheckResult{} = result) do
    project = Repo.get!(Project, check.project_id)
    bot = Accounts.get_or_create_bot_user!(account)

    incident_attrs = %{
      fingerprint: "check_#{check.id}",
      title: incident_title(check),
      severity: :critical,
      source: "monitoring",
      metadata: incident_metadata(check, result),
      reopen_window_hours: check.reopen_window_hours
    }

    occurrence_attrs = %{
      context: occurrence_context(check, result)
    }

    case Tracking.report_incident(account, bot, project.id, incident_attrs, occurrence_attrs) do
      {:ok, incident, status} ->
        link_check_and_result(check, result, incident, status)
        :ok

      {:error, _changeset} = error ->
        error
    end
  end

  @doc """
  Convenience wrapper used by the worker — looks up the account from
  the check's project and delegates to `create_or_reopen_incident/3`.
  """
  def create_or_reopen_incident(%Check{} = check, %CheckResult{} = result) do
    project = Repo.get!(Project, check.project_id) |> Repo.preload(:account)
    create_or_reopen_incident(project.account, check, result)
  end

  @doc """
  Called when a check is observed as up after being down. Resolves the
  incident and clears `current_issue_id` on the check.
  """
  def handle_recovery(%Check{current_issue_id: nil}), do: :ok

  def handle_recovery(%Check{current_issue_id: issue_id} = check) do
    case Repo.get(Issue, issue_id) do
      %Issue{status: status} = _issue when status in [:new, :in_progress] ->
        resolve_and_cleanup(check)

      _ ->
        Monitoring.update_runtime_fields(check, %{current_issue_id: nil})
        :ok
    end
  end

  defp resolve_and_cleanup(%Check{} = check) do
    account = get_check_account(check)

    case Tracking.get_incident_by_fingerprint(account, "check_#{check.id}") do
      nil ->
        # No incident found, just clear the check state
        Monitoring.update_runtime_fields(check, %{current_issue_id: nil, status: :up})
        :ok

      incident ->
        {:ok, _} = Tracking.resolve_incident(incident)

        {:ok, _} =
          Monitoring.update_runtime_fields(check, %{current_issue_id: nil, status: :up})

        :ok
    end
  end

  defp get_check_account(%Check{} = check) do
    project = Repo.get!(Project, check.project_id) |> Repo.preload(:account)
    project.account
  end

  defp link_check_and_result(%Check{} = check, %CheckResult{} = result, incident, status) do
    issue_id = incident.issue_id

    if status in [:created, :reopened] do
      {:ok, _check} =
        Monitoring.update_runtime_fields(check, %{
          status: :down,
          current_issue_id: issue_id
        })
    end

    result
    |> Ecto.Changeset.change(issue_id: issue_id)
    |> Repo.update()
  end

  defp incident_title(%Check{name: name}), do: "DOWN: #{name}"

  defp incident_metadata(%Check{} = check, %CheckResult{} = result) do
    %{
      "check_id" => check.id,
      "url" => check.url,
      "consecutive_failures" => check.consecutive_failures,
      "latest_error" => result.error || "n/a",
      "last_status_code" => result.status_code
    }
  end

  defp occurrence_context(%Check{} = check, %CheckResult{} = result) do
    %{
      "consecutive_failures" => check.consecutive_failures,
      "error" => result.error || "n/a",
      "status_code" => result.status_code
    }
  end
end
