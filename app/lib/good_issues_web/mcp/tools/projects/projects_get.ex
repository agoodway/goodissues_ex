defmodule GIWeb.MCP.Tools.Projects.ProjectsGet do
  @moduledoc "Get a project by ID"
  use Anubis.Server.Component, type: :tool

  alias GI.Tracking
  alias GIWeb.MCP.Tools.Base

  @impl true
  def description, do: "Get a project by ID"

  schema do
    field :id, :string, required: true, doc: "Project ID (UUID)"
  end

  @impl true
  def execute(params, frame) do
    Base.with_scope(frame, "projects:read", fn api_key ->
      account = Base.get_account(api_key)
      id = params[:id] || params["id"]

      case Tracking.get_project(account, id) do
        nil ->
          {:reply, Base.error_response("Resource not found"), frame.assigns}

        project ->
          {:reply, Base.success_response(serialize_project(project)), frame.assigns}
      end
    end)
    |> wrap_frame(frame)
  end

  defp serialize_project(project) do
    %{
      id: project.id,
      name: project.name,
      description: project.description,
      prefix: project.prefix,
      inserted_at: DateTime.to_iso8601(project.inserted_at),
      updated_at: DateTime.to_iso8601(project.updated_at)
    }
  end

  defp wrap_frame({:reply, response, _state}, frame), do: {:reply, response, frame}
end
