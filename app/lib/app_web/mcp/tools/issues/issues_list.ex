defmodule FFWeb.MCP.Tools.Issues.IssuesList do
  @moduledoc "List issues with filtering and pagination"
  use Anubis.Server.Component, type: :tool

  alias FF.Tracking
  alias FFWeb.MCP.Tools.Base

  @impl true
  def description, do: "List issues with optional filters and pagination"

  schema do
    field :project_id, :string, doc: "Filter by project ID (UUID)"
    field :status, :string, doc: "Filter by status: new, in_progress, archived"
    field :type, :string, doc: "Filter by type: bug, incident, feature_request"
    field :page, :integer, doc: "Page number (1-indexed)"
    field :per_page, :integer, doc: "Results per page (max 100)"
  end

  @impl true
  def execute(params, frame) do
    Base.with_scope(frame, "issues:read", fn api_key ->
      account = Base.get_account(api_key)
      filters = build_filters(params)

      result = Tracking.list_issues_paginated(account, filters)

      data = Enum.map(result.issues, &serialize_issue/1)

      meta = %{
        page: result.page,
        per_page: result.per_page,
        total_count: result.total,
        total_pages: result.total_pages,
        has_next: result.page < result.total_pages,
        has_prev: result.page > 1
      }

      {:reply, Base.list_response(data, meta), frame.assigns}
    end)
    |> wrap_frame(frame)
  end

  defp build_filters(params) do
    %{}
    |> maybe_add_filter(:project_id, params[:project_id] || params["project_id"])
    |> maybe_add_filter(:status, params[:status] || params["status"])
    |> maybe_add_filter(:type, params[:type] || params["type"])
    |> maybe_add_filter(:page, params[:page] || params["page"])
    |> maybe_add_filter(:per_page, params[:per_page] || params["per_page"])
  end

  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, _key, ""), do: filters
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)

  defp serialize_issue(issue) do
    %{
      id: issue.id,
      title: issue.title,
      description: issue.description,
      number: issue.number,
      type: to_string(issue.type),
      status: to_string(issue.status),
      priority: to_string(issue.priority),
      project_id: issue.project_id,
      project: serialize_project(issue.project),
      inserted_at: DateTime.to_iso8601(issue.inserted_at),
      updated_at: DateTime.to_iso8601(issue.updated_at)
    }
  end

  defp serialize_project(nil), do: nil

  defp serialize_project(project) do
    %{
      id: project.id,
      name: project.name,
      prefix: project.prefix
    }
  end

  defp wrap_frame({:reply, response, _state}, frame), do: {:reply, response, frame}
end
