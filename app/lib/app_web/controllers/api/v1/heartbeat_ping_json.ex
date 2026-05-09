defmodule FFWeb.Api.V1.HeartbeatPingJSON do
  @moduledoc "JSON rendering for HeartbeatPing resources."

  alias FF.Monitoring.HeartbeatPing

  def index(%{
        pings: pings,
        page: page,
        per_page: per_page,
        total: total,
        total_pages: total_pages
      }) do
    %{
      data: for(ping <- pings, do: data(ping)),
      meta: %{
        page: page,
        per_page: per_page,
        total: total,
        total_pages: total_pages
      }
    }
  end

  defp data(%HeartbeatPing{} = ping) do
    %{
      id: ping.id,
      kind: ping.kind,
      exit_code: ping.exit_code,
      payload: ping.payload,
      duration_ms: ping.duration_ms,
      pinged_at: ping.pinged_at,
      heartbeat_id: ping.heartbeat_id,
      issue_id: ping.issue_id
    }
  end
end
