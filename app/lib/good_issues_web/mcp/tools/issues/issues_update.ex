defmodule FFWeb.MCP.Tools.Issues.IssuesUpdate do
  @moduledoc "Update an existing issue"
  use Anubis.Server.Component, type: :tool

  alias FF.Tracking
  alias FFWeb.MCP.Tools.Base

  @impl true
  def description, do: "Update an existing issue"

  schema do
    field :id, :string, required: true, doc: "Issue ID (UUID)"
    field :title, :string, doc: "New title"
    field :description, :string, doc: "New description"
    field :status, :string, doc: "New status: new, in_progress, archived"
    field :priority, :string, doc: "New priority: low, medium, high, critical"
    field :type, :string, doc: "New type: bug, incident, feature_request"
  end

  @impl true
  def execute(params, frame) do
    Base.with_scope(frame, "issues:write", fn api_key ->
      account = Base.get_account(api_key)
      id = params[:id] || params["id"]

      case Tracking.get_issue(account, id) do
        nil ->
          {:reply, Base.error_response("Resource not found"), frame.assigns}

        issue ->
          issue
          |> Tracking.update_issue(build_attrs(params))
          |> update_issue_response(frame)
      end
    end)
    |> wrap_frame(frame)
  end

  defp update_issue_response({:ok, updated_issue}, frame) do
    updated_issue = FF.Repo.preload(updated_issue, :project)
    {:reply, Base.success_response(serialize_issue(updated_issue)), frame.assigns}
  end

  defp update_issue_response({:error, changeset}, frame) do
    {:reply, Base.changeset_error_response(changeset), frame.assigns}
  end

  defp build_attrs(params) do
    %{}
    |> maybe_add_attr(:title, params[:title] || params["title"])
    |> maybe_add_attr(:description, params[:description] || params["description"])
    |> maybe_add_attr(:status, parse_status(params[:status] || params["status"]))
    |> maybe_add_attr(:priority, parse_priority(params[:priority] || params["priority"]))
    |> maybe_add_attr(:type, parse_type(params[:type] || params["type"]))
  end

  defp maybe_add_attr(attrs, _key, nil), do: attrs
  defp maybe_add_attr(attrs, key, value), do: Map.put(attrs, key, value)

  defp parse_status(nil), do: nil
  defp parse_status("new"), do: :new
  defp parse_status("in_progress"), do: :in_progress
  defp parse_status("archived"), do: :archived
  defp parse_status(other), do: other

  defp parse_priority(nil), do: nil
  defp parse_priority("low"), do: :low
  defp parse_priority("medium"), do: :medium
  defp parse_priority("high"), do: :high
  defp parse_priority("critical"), do: :critical
  defp parse_priority(other), do: other

  defp parse_type(nil), do: nil
  defp parse_type("bug"), do: :bug
  defp parse_type("incident"), do: :incident
  defp parse_type("feature_request"), do: :feature_request
  defp parse_type(other), do: other

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
