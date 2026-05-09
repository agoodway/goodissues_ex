defmodule GIWeb.Api.V1.HeartbeatController do
  use GIWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GI.Monitoring
  alias GI.Monitoring.Heartbeat
  alias GIWeb.Api.V1.Schemas.Heartbeat, as: HBSchemas

  plug GIWeb.Plugs.ApiAuth,
       {:require_scope, "heartbeats:read"} when action in [:index, :show]

  plug GIWeb.Plugs.ApiAuth,
       {:require_scope, "heartbeats:write"} when action in [:create, :update, :delete]

  action_fallback GIWeb.FallbackController

  tags(["Heartbeats"])

  operation(:index,
    summary: "List heartbeats for a project",
    parameters: [
      project_id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        required: true
      ],
      page: [in: :query, schema: %OpenApiSpex.Schema{type: :integer, minimum: 1}],
      per_page: [
        in: :query,
        schema: %OpenApiSpex.Schema{type: :integer, minimum: 1, maximum: 100}
      ]
    ],
    responses: [
      ok: {"Heartbeat list", "application/json", HBSchemas.HeartbeatListResponse},
      bad_request: {"Bad request", "application/json", GIWeb.ErrorJSON},
      not_found: {"Not found", "application/json", GIWeb.ErrorJSON},
      unauthorized: {"Unauthorized", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def index(conn, %{"project_id" => project_id} = params) do
    with :ok <- GIWeb.Api.V1.PaginationHelpers.validate_pagination(params),
         {:ok, _project} <- ensure_project(conn, project_id) do
      result = Monitoring.list_heartbeats(conn.assigns.current_account, project_id, params)

      render(conn, :index,
        heartbeats: result.heartbeats,
        page: result.page,
        per_page: result.per_page,
        total: result.total,
        total_pages: result.total_pages
      )
    end
  end

  operation(:show,
    summary: "Get a heartbeat",
    parameters: [
      project_id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        required: true
      ],
      heartbeat_id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        required: true
      ]
    ],
    responses: [
      ok: {"Heartbeat", "application/json", HBSchemas.HeartbeatResponse},
      not_found: {"Not found", "application/json", GIWeb.ErrorJSON},
      unauthorized: {"Unauthorized", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def show(conn, %{"project_id" => project_id, "heartbeat_id" => heartbeat_id}) do
    case Monitoring.get_heartbeat(conn.assigns.current_account, project_id, heartbeat_id) do
      nil -> {:error, :not_found}
      heartbeat -> render(conn, :show, heartbeat: heartbeat)
    end
  end

  operation(:create,
    summary: "Create a heartbeat",
    parameters: [
      project_id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        required: true
      ]
    ],
    request_body: {"Heartbeat params", "application/json", HBSchemas.HeartbeatRequest},
    responses: [
      created: {"Heartbeat created", "application/json", HBSchemas.HeartbeatCreateResponse},
      unprocessable_entity: {"Validation error", "application/json", GIWeb.ChangesetJSON},
      not_found: {"Not found", "application/json", GIWeb.ErrorJSON},
      unauthorized: {"Unauthorized", "application/json", GIWeb.ErrorJSON},
      forbidden: {"Forbidden", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def create(conn, %{"project_id" => project_id} = params) do
    attrs = Map.put(params, "project_id", project_id)

    with {:ok, _project} <- ensure_project(conn, project_id),
         {:ok, %Heartbeat{} = heartbeat} <-
           Monitoring.create_heartbeat(
             conn.assigns.current_account,
             conn.assigns.current_user,
             attrs
           ) do
      conn
      |> put_status(:created)
      |> render(:created, heartbeat: heartbeat)
    end
  end

  operation(:update,
    summary: "Update a heartbeat",
    parameters: [
      project_id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        required: true
      ],
      heartbeat_id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        required: true
      ]
    ],
    request_body: {"Heartbeat params", "application/json", HBSchemas.HeartbeatUpdateRequest},
    responses: [
      ok: {"Heartbeat updated", "application/json", HBSchemas.HeartbeatResponse},
      not_found: {"Not found", "application/json", GIWeb.ErrorJSON},
      unprocessable_entity: {"Validation error", "application/json", GIWeb.ChangesetJSON},
      unauthorized: {"Unauthorized", "application/json", GIWeb.ErrorJSON},
      forbidden: {"Forbidden", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def update(conn, %{"project_id" => project_id, "heartbeat_id" => heartbeat_id} = params) do
    case Monitoring.get_heartbeat(conn.assigns.current_account, project_id, heartbeat_id) do
      nil ->
        {:error, :not_found}

      heartbeat ->
        with {:ok, %Heartbeat{} = updated} <- Monitoring.update_heartbeat(heartbeat, params) do
          render(conn, :show, heartbeat: updated)
        end
    end
  end

  operation(:delete,
    summary: "Delete a heartbeat",
    parameters: [
      project_id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        required: true
      ],
      heartbeat_id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        required: true
      ]
    ],
    responses: [
      no_content: "Heartbeat deleted",
      not_found: {"Not found", "application/json", GIWeb.ErrorJSON},
      unauthorized: {"Unauthorized", "application/json", GIWeb.ErrorJSON},
      forbidden: {"Forbidden", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def delete(conn, %{"project_id" => project_id, "heartbeat_id" => heartbeat_id}) do
    case Monitoring.get_heartbeat(conn.assigns.current_account, project_id, heartbeat_id) do
      nil ->
        {:error, :not_found}

      heartbeat ->
        with {:ok, %Heartbeat{}} <- Monitoring.delete_heartbeat(heartbeat) do
          send_resp(conn, :no_content, "")
        end
    end
  end

  defp ensure_project(conn, project_id) do
    case GI.Tracking.get_project(conn.assigns.current_account, project_id) do
      nil -> {:error, :not_found}
      project -> {:ok, project}
    end
  end
end
