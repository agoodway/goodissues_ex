defmodule FFWeb.Api.V1.ProjectJSON do
  @moduledoc """
  JSON rendering for Project resources.
  """

  alias FF.Tracking.Project

  def index(%{
        projects: projects,
        page: page,
        per_page: per_page,
        total: total,
        total_pages: total_pages
      }) do
    %{
      data: for(project <- projects, do: data(project)),
      meta: %{
        page: page,
        per_page: per_page,
        total: total,
        total_pages: total_pages
      }
    }
  end

  def show(%{project: project}) do
    %{data: data(project)}
  end

  defp data(%Project{} = project) do
    %{
      id: project.id,
      name: project.name,
      description: project.description,
      inserted_at: project.inserted_at,
      updated_at: project.updated_at
    }
  end
end
