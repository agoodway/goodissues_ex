defmodule GI.Monitoring.HeartbeatIncidentLifecycle do
  @moduledoc """
  Heartbeat-specific incident lifecycle wrapper.

  Applies the same create/reopen/archive rules as
  `GI.Monitoring.IncidentLifecycle` but with heartbeat and heartbeat-ping
  inputs. Uses `GI.Accounts.get_or_create_bot_user!/1` so bot-authored
  issues never consume a real user seat.

  Delegates to `GI.Tracking.report_incident/5` and
  `GI.Tracking.resolve_incident/2` for incident lifecycle management.
  """

  alias GI.Accounts
  alias GI.Monitoring
  alias GI.Monitoring.{Heartbeat, HeartbeatPing}
  alias GI.Repo
  alias GI.Tracking
  alias GI.Tracking.{Issue, Project}

  @doc """
  Called when a heartbeat has crossed `failure_threshold`. Creates a new
  incident, reopens a recently archived one, or adds an occurrence
  if one is already open. Returns `{:ok, issue}` on create/reopen,
  `:ok` on no-op, or `{:error, changeset}` on failure.
  """
  def create_or_reopen_incident(%Heartbeat{} = heartbeat, ping_or_nil \\ nil) do
    project = Repo.get!(Project, heartbeat.project_id) |> Repo.preload(:account)
    account = project.account
    bot = Accounts.get_or_create_bot_user!(account)

    incident_attrs = %{
      fingerprint: "heartbeat_#{heartbeat.id}",
      title: "DOWN: #{heartbeat.name}",
      severity: :critical,
      source: "heartbeat",
      metadata: incident_metadata(heartbeat),
      reopen_window_hours: heartbeat.reopen_window_hours
    }

    occurrence_attrs = %{
      context: occurrence_context(heartbeat)
    }

    case Tracking.report_incident(account, bot, project.id, incident_attrs, occurrence_attrs) do
      {:ok, incident, status} ->
        link_heartbeat_and_ping(heartbeat, ping_or_nil, incident, status)

      {:error, _changeset} = error ->
        error
    end
  end

  @doc """
  Called when a heartbeat recovers (success ping while status is :down).
  Resolves the incident and clears `current_issue_id`.
  """
  def handle_recovery(%Heartbeat{current_issue_id: nil}), do: :ok

  def handle_recovery(%Heartbeat{current_issue_id: issue_id} = heartbeat) do
    case Repo.get(Issue, issue_id) do
      %Issue{status: status} = _issue when status in [:new, :in_progress] ->
        resolve_and_cleanup(heartbeat)

      _ ->
        Monitoring.update_heartbeat_runtime(heartbeat, %{current_issue_id: nil})
        :ok
    end
  end

  defp resolve_and_cleanup(%Heartbeat{} = heartbeat) do
    project = Repo.get!(Project, heartbeat.project_id) |> Repo.preload(:account)
    account = project.account

    case Tracking.get_incident_by_fingerprint(account, "heartbeat_#{heartbeat.id}") do
      nil ->
        Monitoring.update_heartbeat_runtime(heartbeat, %{current_issue_id: nil, status: :up})
        :ok

      incident ->
        {:ok, _} = Tracking.resolve_incident(incident)

        {:ok, _} =
          Monitoring.update_heartbeat_runtime(heartbeat, %{current_issue_id: nil, status: :up})

        :ok
    end
  end

  defp link_heartbeat_and_ping(heartbeat, ping_or_nil, incident, status) do
    issue_id = incident.issue_id

    if status in [:created, :reopened] do
      {:ok, _} =
        Monitoring.update_heartbeat_runtime(heartbeat, %{
          status: :down,
          current_issue_id: issue_id
        })
    end

    maybe_link_ping(ping_or_nil, incident)

    case status do
      :created -> {:ok, Repo.get!(Issue, issue_id)}
      :reopened -> {:ok, Repo.get!(Issue, issue_id)}
      :occurrence_added -> :ok
    end
  end

  defp maybe_link_ping(nil, _incident), do: :ok

  defp maybe_link_ping(%HeartbeatPing{} = ping, incident) do
    ping
    |> Ecto.Changeset.change(issue_id: incident.issue_id)
    |> Repo.update()
  end

  defp incident_metadata(%Heartbeat{} = hb) do
    %{
      "heartbeat_id" => hb.id,
      "consecutive_failures" => hb.consecutive_failures,
      "interval_seconds" => hb.interval_seconds,
      "grace_seconds" => hb.grace_seconds
    }
  end

  defp occurrence_context(%Heartbeat{} = hb) do
    %{
      "consecutive_failures" => hb.consecutive_failures,
      "interval_seconds" => hb.interval_seconds,
      "grace_seconds" => hb.grace_seconds
    }
  end
end
