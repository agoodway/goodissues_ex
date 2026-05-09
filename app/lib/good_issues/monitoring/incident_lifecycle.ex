defmodule FF.Monitoring.IncidentLifecycle do
  @moduledoc """
  Auto-creates, reopens, and archives incident issues based on check
  state transitions.

  Called from `FF.Monitoring.Workers.CheckRunner` after each check
  execution. Uses `FF.Accounts.get_or_create_bot_user!/1` so bot-authored
  issues never consume a real user seat.
  """

  alias FF.Accounts
  alias FF.Accounts.Account
  alias FF.Monitoring
  alias FF.Monitoring.{Check, CheckResult}
  alias FF.Repo
  alias FF.Tracking
  alias FF.Tracking.{Issue, Project}

  @doc """
  Called when a check has crossed `failure_threshold`. Either creates a
  new incident, reopens a recently archived one, or no-ops if an open
  incident already exists.

  Pass the account explicitly to avoid an extra lookup; it must be the
  account that owns the check's project.
  """
  def create_or_reopen_incident(%Account{} = account, %Check{} = check, %CheckResult{} = result) do
    project = Repo.get!(Project, check.project_id)

    case Monitoring.find_incident_issue(check) do
      {:open, %Issue{}} ->
        :ok

      {:reopen, %Issue{} = issue} ->
        reopen_issue(check, issue, result)

      :none ->
        create_new_incident(account, project, check, result)
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
  Called when a check is observed as up after being down. Archives any
  open incident issue and clears `current_issue_id` on the check.
  """
  def handle_recovery(%Check{current_issue_id: nil}), do: :ok

  def handle_recovery(%Check{current_issue_id: issue_id} = check) do
    case Repo.get(Issue, issue_id) do
      %Issue{status: status} = issue when status in [:new, :in_progress] ->
        archive_incident(check, issue)

      _ ->
        Monitoring.update_runtime_fields(check, %{current_issue_id: nil})
        :ok
    end
  end

  @doc """
  Archives an open incident and clears the check's `current_issue_id`.
  """
  def archive_incident(%Check{} = check, %Issue{} = issue) do
    {:ok, _archived} = Tracking.update_issue(issue, %{status: :archived})

    {:ok, _check} =
      Monitoring.update_runtime_fields(check, %{
        current_issue_id: nil,
        status: :up
      })

    :ok
  end

  defp create_new_incident(account, project, check, result) do
    bot = Accounts.get_or_create_bot_user!(account)

    attrs = %{
      title: incident_title(check),
      description: incident_description(check, result),
      type: :incident,
      priority: :critical,
      project_id: project.id
    }

    case Tracking.create_issue(account, bot, attrs) do
      {:ok, issue} ->
        link_check_and_result(check, result, issue)
        :ok

      {:error, _changeset} = error ->
        error
    end
  end

  defp reopen_issue(%Check{} = check, %Issue{} = issue, %CheckResult{} = result) do
    case Tracking.update_issue(issue, %{status: :in_progress}) do
      {:ok, reopened} ->
        link_check_and_result(check, result, reopened)
        :ok

      {:error, _changeset} = error ->
        error
    end
  end

  defp link_check_and_result(%Check{} = check, %CheckResult{} = result, %Issue{} = issue) do
    {:ok, _check} =
      Monitoring.update_runtime_fields(check, %{
        status: :down,
        current_issue_id: issue.id
      })

    result
    |> Ecto.Changeset.change(issue_id: issue.id)
    |> Repo.update()
  end

  defp incident_title(%Check{name: name}), do: "DOWN: #{name}"

  defp incident_description(%Check{} = check, %CheckResult{} = result) do
    """
    Check `#{check.name}` is failing.

    URL: #{check.url}
    Consecutive failures: #{check.consecutive_failures}
    Latest error: #{result.error || "n/a"}
    Last status code: #{format_status_code(result.status_code)}
    """
  end

  defp format_status_code(nil), do: "n/a"
  defp format_status_code(code), do: Integer.to_string(code)
end
