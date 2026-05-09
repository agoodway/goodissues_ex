defmodule FFWeb.Api.V1.HeartbeatJSON do
  @moduledoc "JSON rendering for Heartbeat resources."

  alias FF.Monitoring.Heartbeat

  def index(%{
        heartbeats: heartbeats,
        page: page,
        per_page: per_page,
        total: total,
        total_pages: total_pages
      }) do
    %{
      data: for(hb <- heartbeats, do: data(hb)),
      meta: %{
        page: page,
        per_page: per_page,
        total: total,
        total_pages: total_pages
      }
    }
  end

  def show(%{heartbeat: heartbeat}), do: %{data: data(heartbeat)}

  def created(%{heartbeat: heartbeat}) do
    %{data: create_data(heartbeat)}
  end

  defp data(%Heartbeat{} = hb) do
    %{
      id: hb.id,
      name: hb.name,
      interval_seconds: hb.interval_seconds,
      grace_seconds: hb.grace_seconds,
      failure_threshold: hb.failure_threshold,
      reopen_window_hours: hb.reopen_window_hours,
      paused: hb.paused,
      status: hb.status,
      consecutive_failures: hb.consecutive_failures,
      last_ping_at: hb.last_ping_at,
      next_due_at: hb.next_due_at,
      alert_rules: hb.alert_rules,
      current_issue_id: hb.current_issue_id,
      project_id: hb.project_id,
      inserted_at: hb.inserted_at,
      updated_at: hb.updated_at
    }
  end

  defp create_data(%Heartbeat{} = hb) do
    base_url = FFWeb.Endpoint.url()

    ping_url =
      "#{base_url}/api/v1/projects/#{hb.project_id}/heartbeats/#{hb.ping_token}/ping"

    data(hb)
    |> Map.put(:ping_token, hb.ping_token)
    |> Map.put(:ping_url, ping_url)
  end
end
