defmodule GIWeb.Api.V1.CheckJSON do
  @moduledoc "JSON rendering for Check resources."

  alias GI.Monitoring.Check

  def index(%{
        checks: checks,
        page: page,
        per_page: per_page,
        total: total,
        total_pages: total_pages
      }) do
    %{
      data: for(check <- checks, do: data(check)),
      meta: %{
        page: page,
        per_page: per_page,
        total: total,
        total_pages: total_pages
      }
    }
  end

  def show(%{check: check}), do: %{data: data(check)}

  defp data(%Check{} = check) do
    %{
      id: check.id,
      name: check.name,
      url: check.url,
      method: check.method,
      interval_seconds: check.interval_seconds,
      expected_status: check.expected_status,
      keyword: check.keyword,
      keyword_absence: check.keyword_absence,
      paused: check.paused,
      status: check.status,
      failure_threshold: check.failure_threshold,
      reopen_window_hours: check.reopen_window_hours,
      consecutive_failures: check.consecutive_failures,
      last_checked_at: check.last_checked_at,
      current_issue_id: check.current_issue_id,
      project_id: check.project_id,
      inserted_at: check.inserted_at,
      updated_at: check.updated_at
    }
  end
end
