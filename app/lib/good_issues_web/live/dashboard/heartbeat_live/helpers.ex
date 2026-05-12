defmodule GIWeb.Dashboard.HeartbeatLive.Helpers do
  @moduledoc false

  def display_status(heartbeat) do
    if heartbeat.paused do
      {"bg-base-content/30", "PAUSED"}
    else
      case heartbeat.status do
        :up -> {"bg-success", "UP"}
        :down -> {"bg-error", "DOWN"}
        _ -> {"bg-base-content/30", "UNKNOWN"}
      end
    end
  end

  def format_interval(seconds) when seconds < 60, do: "#{seconds}s"
  def format_interval(seconds) when rem(seconds, 60) == 0, do: "#{div(seconds, 60)}m"
  def format_interval(seconds), do: "#{div(seconds, 60)}m #{rem(seconds, 60)}s"

  def format_relative_time(nil), do: "Never"

  def format_relative_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3600)}h ago"
      diff < 604_800 -> "#{div(diff, 86_400)}d ago"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end
end
