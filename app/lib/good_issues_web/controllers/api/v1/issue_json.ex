defmodule GIWeb.Api.V1.IssueJSON do
  @moduledoc """
  JSON rendering for Issue resources.
  """

  alias GI.Tracking.Issue

  def index(%{
        issues: issues,
        page: page,
        per_page: per_page,
        total: total,
        total_pages: total_pages
      }) do
    %{
      data: for(issue <- issues, do: data(issue)),
      meta: %{
        page: page,
        per_page: per_page,
        total: total,
        total_pages: total_pages
      }
    }
  end

  def show(%{issue: issue}) do
    %{data: data(issue)}
  end

  defp data(%Issue{} = issue) do
    %{
      id: issue.id,
      key: Issue.issue_key(issue),
      number: issue.number,
      title: issue.title,
      description: issue.description,
      type: issue.type,
      status: issue.status,
      priority: issue.priority,
      project_id: issue.project_id,
      submitter_id: issue.submitter_id,
      submitter_email: issue.submitter_email,
      archived_at: issue.archived_at,
      inserted_at: issue.inserted_at,
      updated_at: issue.updated_at
    }
  end
end
