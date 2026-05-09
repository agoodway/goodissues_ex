defmodule GIWeb.Api.V1.ProjectController do
  use GIWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GI.Tracking
  alias GI.Tracking.Project
  alias GIWeb.Api.V1.Schemas.Project, as: ProjectSchemas

  plug GIWeb.Plugs.ApiAuth, {:require_scope, "projects:read"} when action in [:index, :show]

  plug GIWeb.Plugs.ApiAuth,
       {:require_scope, "projects:write"} when action in [:create, :update, :delete]

  action_fallback GIWeb.FallbackController

  tags(["Projects"])

  operation(:index,
    summary: "List projects",
    description: "Returns all projects for the authenticated user's account",
    parameters: [
      page: [
        in: :query,
        schema: %OpenApiSpex.Schema{type: :integer, minimum: 1},
        description: "Page number"
      ],
      per_page: [
        in: :query,
        schema: %OpenApiSpex.Schema{type: :integer, minimum: 1, maximum: 100},
        description: "Results per page"
      ]
    ],
    responses: [
      ok: {"Project list", "application/json", ProjectSchemas.ProjectListResponse},
      bad_request: {"Bad request", "application/json", GIWeb.ErrorJSON},
      unauthorized: {"Unauthorized", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def index(conn, params) do
    with :ok <- GIWeb.Api.V1.PaginationHelpers.validate_pagination(params) do
      result = Tracking.list_projects_paginated(conn.assigns.current_account, params)

      render(conn, :index,
        projects: result.projects,
        page: result.page,
        per_page: result.per_page,
        total: result.total,
        total_pages: result.total_pages
      )
    end
  end

  operation(:show,
    summary: "Get project",
    description: "Returns a specific project by ID",
    parameters: [
      id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        description: "Project ID",
        required: true
      ]
    ],
    responses: [
      ok: {"Project", "application/json", ProjectSchemas.ProjectResponse},
      not_found: {"Not found", "application/json", GIWeb.ErrorJSON},
      unauthorized: {"Unauthorized", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def show(conn, %{"id" => id}) do
    case Tracking.get_project(conn.assigns.current_account, id) do
      nil -> {:error, :not_found}
      project -> render(conn, :show, project: project)
    end
  end

  operation(:create,
    summary: "Create project",
    description: "Creates a new project in the authenticated user's account",
    request_body: {"Project params", "application/json", ProjectSchemas.ProjectRequest},
    responses: [
      created: {"Project created", "application/json", ProjectSchemas.ProjectResponse},
      unprocessable_entity: {"Validation error", "application/json", GIWeb.ChangesetJSON},
      unauthorized: {"Unauthorized", "application/json", GIWeb.ErrorJSON},
      forbidden: {"Forbidden", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def create(conn, params) do
    with {:ok, %Project{} = project} <-
           Tracking.create_project(conn.assigns.current_account, params) do
      conn
      |> put_status(:created)
      |> render(:show, project: project)
    end
  end

  operation(:update,
    summary: "Update project",
    description: "Updates an existing project",
    parameters: [
      id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        description: "Project ID",
        required: true
      ]
    ],
    request_body: {"Project params", "application/json", ProjectSchemas.ProjectRequest},
    responses: [
      ok: {"Project updated", "application/json", ProjectSchemas.ProjectResponse},
      not_found: {"Not found", "application/json", GIWeb.ErrorJSON},
      unprocessable_entity: {"Validation error", "application/json", GIWeb.ChangesetJSON},
      unauthorized: {"Unauthorized", "application/json", GIWeb.ErrorJSON},
      forbidden: {"Forbidden", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def update(conn, %{"id" => id} = params) do
    case Tracking.get_project(conn.assigns.current_account, id) do
      nil ->
        {:error, :not_found}

      project ->
        with {:ok, %Project{} = project} <- Tracking.update_project(project, params) do
          render(conn, :show, project: project)
        end
    end
  end

  operation(:delete,
    summary: "Delete project",
    description: "Deletes a project",
    parameters: [
      id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        description: "Project ID",
        required: true
      ]
    ],
    responses: [
      no_content: "Project deleted",
      not_found: {"Not found", "application/json", GIWeb.ErrorJSON},
      unauthorized: {"Unauthorized", "application/json", GIWeb.ErrorJSON},
      forbidden: {"Forbidden", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def delete(conn, %{"id" => id}) do
    case Tracking.get_project(conn.assigns.current_account, id) do
      nil ->
        {:error, :not_found}

      project ->
        with {:ok, %Project{}} <- Tracking.delete_project(project) do
          send_resp(conn, :no_content, "")
        end
    end
  end
end
