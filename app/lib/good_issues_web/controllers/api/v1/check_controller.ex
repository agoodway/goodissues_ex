defmodule FFWeb.Api.V1.CheckController do
  use FFWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias FF.Monitoring
  alias FF.Monitoring.Check
  alias FFWeb.Api.V1.Schemas.Check, as: CheckSchemas

  plug FFWeb.Plugs.ApiAuth, {:require_scope, "checks:read"} when action in [:index, :show]

  plug FFWeb.Plugs.ApiAuth,
       {:require_scope, "checks:write"} when action in [:create, :update, :delete]

  action_fallback FFWeb.FallbackController

  tags(["Checks"])

  operation(:index,
    summary: "List checks for a project",
    parameters: [
      project_id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        required: true
      ],
      page: [
        in: :query,
        schema: %OpenApiSpex.Schema{type: :integer, minimum: 1}
      ],
      per_page: [
        in: :query,
        schema: %OpenApiSpex.Schema{type: :integer, minimum: 1, maximum: 100}
      ]
    ],
    responses: [
      ok: {"Check list", "application/json", CheckSchemas.CheckListResponse},
      bad_request: {"Bad request", "application/json", FFWeb.ErrorJSON},
      not_found: {"Not found", "application/json", FFWeb.ErrorJSON},
      unauthorized: {"Unauthorized", "application/json", FFWeb.ErrorJSON}
    ]
  )

  def index(conn, %{"project_id" => project_id} = params) do
    with :ok <- FFWeb.Api.V1.PaginationHelpers.validate_pagination(params),
         {:ok, _project} <- ensure_project(conn, project_id) do
      result = Monitoring.list_checks(conn.assigns.current_account, project_id, params)

      render(conn, :index,
        checks: result.checks,
        page: result.page,
        per_page: result.per_page,
        total: result.total,
        total_pages: result.total_pages
      )
    end
  end

  operation(:show,
    summary: "Get a check",
    parameters: [
      project_id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        required: true
      ],
      check_id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        required: true
      ]
    ],
    responses: [
      ok: {"Check", "application/json", CheckSchemas.CheckResponse},
      not_found: {"Not found", "application/json", FFWeb.ErrorJSON},
      unauthorized: {"Unauthorized", "application/json", FFWeb.ErrorJSON}
    ]
  )

  def show(conn, %{"project_id" => project_id, "check_id" => check_id}) do
    case Monitoring.get_check(conn.assigns.current_account, project_id, check_id) do
      nil -> {:error, :not_found}
      check -> render(conn, :show, check: check)
    end
  end

  operation(:create,
    summary: "Create a check",
    parameters: [
      project_id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        required: true
      ]
    ],
    request_body: {"Check params", "application/json", CheckSchemas.CheckRequest},
    responses: [
      created: {"Check created", "application/json", CheckSchemas.CheckResponse},
      unprocessable_entity: {"Validation error", "application/json", FFWeb.ChangesetJSON},
      not_found: {"Not found", "application/json", FFWeb.ErrorJSON},
      unauthorized: {"Unauthorized", "application/json", FFWeb.ErrorJSON},
      forbidden: {"Forbidden", "application/json", FFWeb.ErrorJSON}
    ]
  )

  def create(conn, %{"project_id" => project_id} = params) do
    attrs = Map.put(params, "project_id", project_id)

    with {:ok, _project} <- ensure_project(conn, project_id),
         {:ok, %Check{} = check} <-
           Monitoring.create_check(
             conn.assigns.current_account,
             conn.assigns.current_user,
             attrs
           ) do
      conn
      |> put_status(:created)
      |> render(:show, check: check)
    end
  end

  operation(:update,
    summary: "Update a check",
    parameters: [
      project_id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        required: true
      ],
      check_id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        required: true
      ]
    ],
    request_body: {"Check params", "application/json", CheckSchemas.CheckUpdateRequest},
    responses: [
      ok: {"Check updated", "application/json", CheckSchemas.CheckResponse},
      not_found: {"Not found", "application/json", FFWeb.ErrorJSON},
      unprocessable_entity: {"Validation error", "application/json", FFWeb.ChangesetJSON},
      unauthorized: {"Unauthorized", "application/json", FFWeb.ErrorJSON},
      forbidden: {"Forbidden", "application/json", FFWeb.ErrorJSON}
    ]
  )

  def update(conn, %{"project_id" => project_id, "check_id" => check_id} = params) do
    case Monitoring.get_check(conn.assigns.current_account, project_id, check_id) do
      nil ->
        {:error, :not_found}

      check ->
        with {:ok, %Check{} = updated} <- Monitoring.update_check(check, params) do
          render(conn, :show, check: updated)
        end
    end
  end

  operation(:delete,
    summary: "Delete a check",
    parameters: [
      project_id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        required: true
      ],
      check_id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        required: true
      ]
    ],
    responses: [
      no_content: "Check deleted",
      not_found: {"Not found", "application/json", FFWeb.ErrorJSON},
      unauthorized: {"Unauthorized", "application/json", FFWeb.ErrorJSON},
      forbidden: {"Forbidden", "application/json", FFWeb.ErrorJSON}
    ]
  )

  def delete(conn, %{"project_id" => project_id, "check_id" => check_id}) do
    case Monitoring.get_check(conn.assigns.current_account, project_id, check_id) do
      nil ->
        {:error, :not_found}

      check ->
        with {:ok, %Check{}} <- Monitoring.delete_check(check) do
          send_resp(conn, :no_content, "")
        end
    end
  end

  defp ensure_project(conn, project_id) do
    case FF.Tracking.get_project(conn.assigns.current_account, project_id) do
      nil -> {:error, :not_found}
      project -> {:ok, project}
    end
  end
end
