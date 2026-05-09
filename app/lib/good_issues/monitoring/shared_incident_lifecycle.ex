defmodule GI.Monitoring.SharedIncidentLifecycle do
  @moduledoc """
  Shared incident lifecycle helpers used by both check and heartbeat
  incident lifecycle modules.

  Provides `classify_incident/3` which determines whether an existing
  issue is open, eligible for reopen, or expired.
  """

  alias GI.Tracking.Issue

  @doc """
  Classifies an existing issue as `:open`, `:reopen`, or `:none` based
  on its status and recency relative to the monitor's `reopen_window_hours`.
  """
  def classify_incident(%Issue{status: status} = issue, _reopen_window_hours, _now)
      when status in [:new, :in_progress] do
    {:open, issue}
  end

  def classify_incident(
        %Issue{status: :archived, archived_at: %DateTime{} = archived_at} = issue,
        reopen_window_hours,
        now
      ) do
    cutoff = DateTime.add(now, -reopen_window_hours * 3600, :second)

    if DateTime.compare(archived_at, cutoff) != :lt do
      {:reopen, issue}
    else
      :none
    end
  end

  def classify_incident(_issue, _reopen_window_hours, _now), do: :none
end
