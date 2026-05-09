defmodule GIWeb.Api.V1.CheckResultJSON do
  @moduledoc "JSON rendering for CheckResult resources."

  alias GI.Monitoring.CheckResult

  def index(%{
        results: results,
        page: page,
        per_page: per_page,
        total: total,
        total_pages: total_pages
      }) do
    %{
      data: for(result <- results, do: data(result)),
      meta: %{
        page: page,
        per_page: per_page,
        total: total,
        total_pages: total_pages
      }
    }
  end

  defp data(%CheckResult{} = result) do
    %{
      id: result.id,
      status: result.status,
      status_code: result.status_code,
      response_ms: result.response_ms,
      error: result.error,
      checked_at: result.checked_at,
      check_id: result.check_id,
      issue_id: result.issue_id
    }
  end
end
