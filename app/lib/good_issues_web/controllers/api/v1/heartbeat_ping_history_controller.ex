defmodule GIWeb.Api.V1.HeartbeatPingHistoryController do
  use GIWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GI.Monitoring
  alias GIWeb.Api.V1.Schemas.Heartbeat, as: HBSchemas

  plug GIWeb.Plugs.ApiAuth, {:require_scope, "heartbeats:read"} when action in [:index]

  action_fallback GIWeb.FallbackController

  tags(["Heartbeats"])

  operation(:index,
    summary: "List pings for a heartbeat",
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
      ],
      page: [in: :query, schema: %OpenApiSpex.Schema{type: :integer, minimum: 1}],
      per_page: [
        in: :query,
        schema: %OpenApiSpex.Schema{type: :integer, minimum: 1, maximum: 100}
      ]
    ],
    responses: [
      ok: {"Heartbeat ping list", "application/json", HBSchemas.HeartbeatPingListResponse},
      bad_request: {"Bad request", "application/json", GIWeb.ErrorJSON},
      not_found: {"Not found", "application/json", GIWeb.ErrorJSON},
      unauthorized: {"Unauthorized", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def index(conn, %{"project_id" => project_id, "heartbeat_id" => heartbeat_id} = params) do
    with :ok <- GIWeb.Api.V1.PaginationHelpers.validate_pagination(params) do
      case Monitoring.get_heartbeat(
             conn.assigns.current_account,
             project_id,
             heartbeat_id
           ) do
        nil ->
          {:error, :not_found}

        heartbeat ->
          result = Monitoring.list_heartbeat_pings(heartbeat, params)

          conn
          |> put_view(GIWeb.Api.V1.HeartbeatPingJSON)
          |> render(:index,
            pings: result.pings,
            page: result.page,
            per_page: result.per_page,
            total: result.total,
            total_pages: result.total_pages
          )
      end
    end
  end
end
