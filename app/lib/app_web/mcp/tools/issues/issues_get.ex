defmodule FFWeb.MCP.Tools.Issues.IssuesGet do
  @moduledoc "Get an issue by ID"
  use Anubis.Server.Component, type: :tool

  alias FF.Tracking
  alias FFWeb.MCP.Tools.Base

  @impl true
  def description, do: "Get an issue by ID"

  schema do
    field :id, :string, required: true, doc: "Issue ID (UUID)"
  end

  @impl true
  def execute(params, frame) do
    Base.with_scope(frame, "issues:read", fn api_key ->
      account = Base.get_account(api_key)
      id = params[:id] || params["id"]

      case Tracking.get_issue(account, id, preload: [:project]) do
        nil ->
          {:reply, Base.error_response("Resource not found"), frame.assigns}

        issue ->
          {:reply, Base.success_response(serialize_issue(issue)), frame.assigns}
      end
    end)
    |> wrap_frame(frame)
  end

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
