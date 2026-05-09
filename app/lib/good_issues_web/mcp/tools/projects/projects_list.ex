defmodule GIWeb.MCP.Tools.Projects.ProjectsList do
  @moduledoc "List projects with pagination"
  use Anubis.Server.Component, type: :tool

  alias GI.Tracking
  alias GIWeb.MCP.Tools.Base

  @impl true
  def description, do: "List projects in the account with pagination"

  schema do
    field :page, :integer, doc: "Page number (1-indexed)"
    field :per_page, :integer, doc: "Results per page (max 250)"
  end

  @impl true
  def execute(params, frame) do
    Base.with_scope(frame, "projects:read", fn api_key ->
      account = Base.get_account(api_key)
      {page, per_page} = Base.get_pagination(params)

      projects = Tracking.list_projects(account)
      total = length(projects)

      # Apply pagination manually since list_projects doesn't support it
      paginated =
        projects
        |> Enum.drop((page - 1) * per_page)
        |> Enum.take(per_page)

      data = Enum.map(paginated, &serialize_project/1)
      meta = Base.build_meta(page, per_page, total)

      {:reply, Base.list_response(data, meta), frame.assigns}
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
