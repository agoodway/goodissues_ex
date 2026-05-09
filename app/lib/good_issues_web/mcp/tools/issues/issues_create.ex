defmodule GIWeb.MCP.Tools.Issues.IssuesCreate do
  @moduledoc "Create a new issue"
  use Anubis.Server.Component, type: :tool

  alias GI.Tracking
  alias GIWeb.MCP.Tools.Base

  @impl true
  def description, do: "Create a new issue in a project"

  schema do
    field :project_id, :string, required: true, doc: "Project ID (UUID)"
    field :title, :string, required: true, doc: "Issue title"
    field :type, :string, required: true, doc: "Issue type: bug, incident, or feature_request"
    field :description, :string, doc: "Issue description"
    field :priority, :string, doc: "Priority: low, medium, high, critical (default: medium)"
  end

  @impl true
  def execute(params, frame) do
    Base.with_scope(frame, "issues:write", fn api_key ->
      account = Base.get_account(api_key)
      user = Base.get_user(api_key)

      attrs = %{
        project_id: params[:project_id] || params["project_id"],
        title: params[:title] || params["title"],
        type: parse_type(params[:type] || params["type"]),
        description: params[:description] || params["description"],
        priority: parse_priority(params[:priority] || params["priority"])
      }

      case Tracking.create_issue(account, user, attrs) do
        {:ok, issue} ->
          {:reply, Base.success_response(serialize_issue(issue)), frame.assigns}

        {:error, changeset} ->
          {:reply, Base.changeset_error_response(changeset), frame.assigns}
      end
    end)
    |> wrap_frame(frame)
  end

  defp parse_type("bug"), do: :bug
  defp parse_type("incident"), do: :incident
  defp parse_type("feature_request"), do: :feature_request
  defp parse_type(other), do: other

  defp parse_priority(nil), do: nil
  defp parse_priority("low"), do: :low
  defp parse_priority("medium"), do: :medium
  defp parse_priority("high"), do: :high
  defp parse_priority("critical"), do: :critical
  defp parse_priority(other), do: other

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
