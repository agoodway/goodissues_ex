defmodule GIWeb.Api.V1.ErrorController do
  use GIWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GI.Tracking
  alias GI.Tracking.Error

  alias GIWeb.Api.V1.Schemas.Error, as: ErrorSchemas

  plug GIWeb.Plugs.ApiAuth,
       {:require_scope, "errors:read"} when action in [:index, :show, :search]

  plug GIWeb.Plugs.ApiAuth, {:require_scope, "errors:write"} when action in [:create, :update]

  action_fallback GIWeb.FallbackController

  tags(["Errors"])

  operation(:index,
    summary: "List errors",
    description: "Returns all errors for the authenticated user's account",
    parameters: [
      status: [
        in: :query,
        schema: ErrorSchemas.ErrorStatus,
        description: "Filter by status"
      ],
      muted: [
        in: :query,
        schema: %OpenApiSpex.Schema{type: :boolean},
        description: "Filter by muted status"
      ],
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
      ok: {"Error list", "application/json", ErrorSchemas.ErrorListResponse},
      unauthorized: {"Unauthorized", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def index(conn, params) do
    with :ok <- GIWeb.Api.V1.PaginationHelpers.validate_pagination(params) do
      filters = build_filters(params)
      result = Tracking.list_errors_paginated(conn.assigns.current_account, filters)

      render(conn, :index,
        errors: result.errors,
        page: result.page,
        per_page: result.per_page,
        total: result.total,
        total_pages: result.total_pages
      )
    end
  end

  defp build_filters(params) do
    %{}
    |> maybe_add_filter(:status, params["status"])
    |> maybe_add_muted_filter(params["muted"])
    |> maybe_add_filter(:page, params["page"])
    |> maybe_add_filter(:per_page, params["per_page"])
  end

  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, _key, ""), do: filters
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)

  defp maybe_add_muted_filter(filters, "true"), do: Map.put(filters, :muted, true)
  defp maybe_add_muted_filter(filters, "false"), do: Map.put(filters, :muted, false)
  defp maybe_add_muted_filter(filters, _), do: filters

  operation(:show,
    summary: "Get error",
    description: "Returns a specific error by ID with paginated occurrences",
    parameters: [
      id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        description: "Error ID",
        required: true
      ],
      page: [
        in: :query,
        schema: %OpenApiSpex.Schema{type: :integer, minimum: 1},
        description: "Occurrences page number"
      ],
      per_page: [
        in: :query,
        schema: %OpenApiSpex.Schema{type: :integer, minimum: 1, maximum: 100},
        description: "Occurrences per page"
      ]
    ],
    responses: [
      ok: {"Error with occurrences", "application/json", ErrorSchemas.ErrorResponse},
      not_found: {"Not found", "application/json", GIWeb.ErrorJSON},
      unauthorized: {"Unauthorized", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def show(conn, %{"id" => id} = params) do
    opts = [
      page: params["page"],
      per_page: params["per_page"]
    ]

    case Tracking.get_error_with_occurrences(conn.assigns.current_account, id, opts) do
      nil -> {:error, :not_found}
      error -> render(conn, :show, error: error)
    end
  end

  operation(:create,
    summary: "Report error",
    description:
      "Reports an error. If fingerprint matches existing error, adds occurrence. Otherwise creates new issue and error.",
    request_body: {"Error params", "application/json", ErrorSchemas.ErrorReportRequest},
    responses: [
      created: {"Error created", "application/json", ErrorSchemas.ErrorResponse},
      ok: {"Occurrence added", "application/json", ErrorSchemas.ErrorResponse},
      unprocessable_entity: {"Validation error", "application/json", GIWeb.ChangesetJSON},
      unauthorized: {"Unauthorized", "application/json", GIWeb.ErrorJSON},
      forbidden: {"Forbidden", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def create(conn, params) do
    error_attrs = %{
      kind: params["kind"],
      reason: params["reason"],
      source_line: params["source_line"] || "-",
      source_function: params["source_function"] || "-",
      fingerprint: params["fingerprint"],
      last_occurrence_at: DateTime.utc_now(:second)
    }

    occurrence_attrs = %{
      reason: params["reason"],
      context: params["context"] || %{},
      breadcrumbs: params["breadcrumbs"] || [],
      stacktrace_lines: normalize_stacktrace_lines(params["stacktrace"])
    }

    project_id = params["project_id"]

    case Tracking.report_error(
           conn.assigns.current_account,
           conn.assigns.current_user,
           project_id,
           error_attrs,
           occurrence_attrs
         ) do
      {:ok, %Error{} = error, status} ->
        error = GI.Repo.preload(error, [:issue, :occurrences])
        http_status = if status == :created, do: :created, else: :ok

        conn
        |> put_status(http_status)
        |> render(:show, error: error)

      {:error, :project_not_found} ->
        {:error, :not_found}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp normalize_stacktrace_lines(nil), do: []
  defp normalize_stacktrace_lines(%{"lines" => lines}) when is_list(lines), do: lines

  defp normalize_stacktrace_lines(lines) when is_list(lines) do
    Enum.map(lines, fn line ->
      %{
        application: line["application"],
        module: line["module"],
        function: line["function"],
        arity: line["arity"],
        file: line["file"],
        line: line["line"]
      }
    end)
  end

  defp normalize_stacktrace_lines(_), do: []

  operation(:update,
    summary: "Update error",
    description: "Updates an error's status or muted flag",
    parameters: [
      id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        description: "Error ID",
        required: true
      ]
    ],
    request_body: {"Error params", "application/json", ErrorSchemas.ErrorUpdateRequest},
    responses: [
      ok: {"Error updated", "application/json", ErrorSchemas.ErrorResponse},
      not_found: {"Not found", "application/json", GIWeb.ErrorJSON},
      unprocessable_entity: {"Validation error", "application/json", GIWeb.ChangesetJSON},
      unauthorized: {"Unauthorized", "application/json", GIWeb.ErrorJSON},
      forbidden: {"Forbidden", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def update(conn, %{"id" => id} = params) do
    case Tracking.get_error(conn.assigns.current_account, id) do
      nil ->
        {:error, :not_found}

      error ->
        attrs = %{}
        attrs = if params["status"], do: Map.put(attrs, :status, params["status"]), else: attrs

        attrs =
          if is_boolean(params["muted"]), do: Map.put(attrs, :muted, params["muted"]), else: attrs

        with {:ok, %Error{} = error} <- Tracking.update_error(error, attrs) do
          error = GI.Repo.preload(error, :issue)
          render(conn, :show, error: error)
        end
    end
  end

  operation(:search,
    summary: "Search errors by stacktrace",
    description: "Searches errors by stacktrace fields (module, function, file)",
    parameters: [
      module: [
        in: :query,
        schema: %OpenApiSpex.Schema{type: :string},
        description: "Search by module name"
      ],
      function: [
        in: :query,
        schema: %OpenApiSpex.Schema{type: :string},
        description: "Search by function name"
      ],
      file: [
        in: :query,
        schema: %OpenApiSpex.Schema{type: :string},
        description: "Search by file path"
      ],
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
      ok: {"Error list", "application/json", ErrorSchemas.ErrorListResponse},
      unauthorized: {"Unauthorized", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def search(conn, params) do
    with :ok <- GIWeb.Api.V1.PaginationHelpers.validate_pagination(params) do
      filters = %{}

      filters =
        if params["module"], do: Map.put(filters, :module, params["module"]), else: filters

      filters =
        if params["function"], do: Map.put(filters, :function, params["function"]), else: filters

      filters = if params["file"], do: Map.put(filters, :file, params["file"]), else: filters
      filters = if params["page"], do: Map.put(filters, :page, params["page"]), else: filters

      filters =
        if params["per_page"], do: Map.put(filters, :per_page, params["per_page"]), else: filters

      result = Tracking.search_errors_by_stacktrace(conn.assigns.current_account, filters)

      render(conn, :index,
        errors: result.errors,
        page: result.page,
        per_page: result.per_page,
        total: result.total,
        total_pages: result.total_pages
      )
    end
  end
end
