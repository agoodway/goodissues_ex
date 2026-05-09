defmodule GIWeb.Api.V1.CheckResultController do
  use GIWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GI.Monitoring
  alias GIWeb.Api.V1.Schemas.Check, as: CheckSchemas

  plug GIWeb.Plugs.ApiAuth, {:require_scope, "checks:read"} when action in [:index]

  action_fallback GIWeb.FallbackController

  tags(["Checks"])

  operation(:index,
    summary: "List results for a check",
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
      ],
      page: [in: :query, schema: %OpenApiSpex.Schema{type: :integer, minimum: 1}],
      per_page: [
        in: :query,
        schema: %OpenApiSpex.Schema{type: :integer, minimum: 1, maximum: 100}
      ]
    ],
    responses: [
      ok: {"Check result list", "application/json", CheckSchemas.CheckResultListResponse},
      bad_request: {"Bad request", "application/json", GIWeb.ErrorJSON},
      not_found: {"Not found", "application/json", GIWeb.ErrorJSON},
      unauthorized: {"Unauthorized", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def index(conn, %{"project_id" => project_id, "check_id" => check_id} = params) do
    with :ok <- GIWeb.Api.V1.PaginationHelpers.validate_pagination(params) do
      case Monitoring.list_check_results(
             conn.assigns.current_account,
             project_id,
             check_id,
             params
           ) do
        nil ->
          {:error, :not_found}

        result ->
          render(conn, :index,
            results: result.results,
            page: result.page,
            per_page: result.per_page,
            total: result.total,
            total_pages: result.total_pages
          )
      end
    end
  end
end
