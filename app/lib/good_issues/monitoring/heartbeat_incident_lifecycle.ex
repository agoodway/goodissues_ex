defmodule FF.Monitoring.HeartbeatIncidentLifecycle do
  @moduledoc """
  Heartbeat-specific incident lifecycle wrapper.

  Applies the same create/reopen/archive rules as
  `FF.Monitoring.IncidentLifecycle` but with heartbeat and heartbeat-ping
  inputs. Uses `FF.Accounts.get_or_create_bot_user!/1` so bot-authored
  issues never consume a real user seat.
  """

  alias FF.Accounts
  alias FF.Monitoring
  alias FF.Monitoring.{Heartbeat, HeartbeatPing, SharedIncidentLifecycle}
  alias FF.Repo
  alias FF.Tracking
  alias FF.Tracking.{Issue, Project}

  @doc """
  Called when a heartbeat has crossed `failure_threshold`. Creates a new
  incident, reopens a recently archived one, or no-ops if one is already
  open. Returns `{:ok, issue}` on create/reopen, `:ok` on no-op, or
  `{:error, changeset}` on failure.
  """
  def create_or_reopen_incident(%Heartbeat{} = heartbeat, ping_or_nil \\ nil) do
    project = Repo.get!(Project, heartbeat.project_id) |> Repo.preload(:account)
    account = project.account

    case find_incident_issue(heartbeat) do
      {:open, %Issue{} = issue} ->
        maybe_link_ping(ping_or_nil, issue)
        :ok

      {:reopen, %Issue{} = issue} ->
        reopen_issue(heartbeat, issue, ping_or_nil)

      :none ->
        create_new_incident(account, project, heartbeat, ping_or_nil)
    end
  end

  @doc """
  Called when a heartbeat recovers (success ping while status is :down).
  Archives the open incident and clears `current_issue_id`.
  """
  def handle_recovery(%Heartbeat{current_issue_id: nil}), do: :ok

  def handle_recovery(%Heartbeat{current_issue_id: issue_id} = heartbeat) do
    case Repo.get(Issue, issue_id) do
      %Issue{status: status} = issue when status in [:new, :in_progress] ->
        archive_incident(heartbeat, issue)

      _ ->
        Monitoring.update_heartbeat_runtime(heartbeat, %{current_issue_id: nil})
        :ok
    end
  end

  defp archive_incident(%Heartbeat{} = heartbeat, %Issue{} = issue) do
    {:ok, _archived} = Tracking.update_issue(issue, %{status: :archived})

    {:ok, _heartbeat} =
      Monitoring.update_heartbeat_runtime(heartbeat, %{
        current_issue_id: nil,
        status: :up
      })

    :ok
  end

  defp find_incident_issue(%Heartbeat{} = heartbeat) do
    now = DateTime.utc_now(:second)

    case current_or_recent_incident(heartbeat) do
      nil -> :none
      %Issue{} = issue -> classify_incident(issue, heartbeat, now)
    end
  end

  defp current_or_recent_incident(%Heartbeat{current_issue_id: nil} = heartbeat) do
    most_recent_incident(heartbeat)
  end

  defp current_or_recent_incident(%Heartbeat{current_issue_id: issue_id}) do
    Repo.get(Issue, issue_id)
  end

  # Finds the most recent incident for this heartbeat, checking both
  # ping-linked issues and issues linked directly to the heartbeat
  # (e.g. from deadline failures which have no ping row).
  defp most_recent_incident(%Heartbeat{id: heartbeat_id}) do
    import Ecto.Query

    # Find the most recent incident directly linked to this heartbeat,
    # regardless of whether it was created via a ping or a deadline failure.
    from(i in Issue,
      where: i.heartbeat_id == ^heartbeat_id,
      where: i.type == :incident,
      order_by: [desc: i.inserted_at, desc: i.id],
      limit: 1
    )
    |> Repo.one()
  end

  defp classify_incident(issue, %Heartbeat{reopen_window_hours: window}, now) do
    SharedIncidentLifecycle.classify_incident(issue, window, now)
  end

  defp create_new_incident(account, project, heartbeat, ping_or_nil) do
    bot = Accounts.get_or_create_bot_user!(account)

    attrs = %{
      title: "DOWN: #{heartbeat.name}",
      description: incident_description(heartbeat),
      type: :incident,
      priority: :critical,
      project_id: project.id,
      heartbeat_id: heartbeat.id
    }

    case Tracking.create_issue(account, bot, attrs) do
      {:ok, issue} ->
        {:ok, _} =
          Monitoring.update_heartbeat_runtime(heartbeat, %{
            status: :down,
            current_issue_id: issue.id
          })

        maybe_link_ping(ping_or_nil, issue)
        {:ok, issue}

      {:error, _changeset} = error ->
        error
    end
  end

  defp reopen_issue(%Heartbeat{} = heartbeat, %Issue{} = issue, ping_or_nil) do
    case Tracking.update_issue(issue, %{status: :in_progress}) do
      {:ok, reopened} ->
        {:ok, _} =
          Monitoring.update_heartbeat_runtime(heartbeat, %{
            status: :down,
            current_issue_id: reopened.id
          })

        maybe_link_ping(ping_or_nil, reopened)
        {:ok, reopened}

      {:error, _changeset} = error ->
        error
    end
  end

  defp maybe_link_ping(nil, _issue), do: :ok

  defp maybe_link_ping(%HeartbeatPing{} = ping, %Issue{} = issue) do
    ping
    |> Ecto.Changeset.change(issue_id: issue.id)
    |> Repo.update()
  end

  defp incident_description(%Heartbeat{} = hb) do
    """
    Heartbeat `#{hb.name}` is failing.

    Consecutive failures: #{hb.consecutive_failures}
    Interval: #{hb.interval_seconds}s + #{hb.grace_seconds}s grace
    """
  end
end
