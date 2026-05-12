defmodule GIWeb.Api.V1.IncidentController do
  use GIWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GI.Tracking
  alias GI.Tracking.Incident

  alias GIWeb.Api.V1.Schemas.Incident, as: IncidentSchemas

  plug GIWeb.Plugs.ApiAuth,
       {:require_scope, "incidents:read"} when action in [:index, :show]

  plug GIWeb.Plugs.ApiAuth,
       {:require_scope, "incidents:write"} when action in [:create, :update, :resolve]

  plug GIWeb.Plugs.ApiRateLimiter, [max_requests: 60, window_ms: 60_000] when action in [:create]

  action_fallback GIWeb.FallbackController

  tags(["Incidents"])

  operation(:index,
    summary: "List incidents",
    description: "Returns all incidents for the authenticated user's account",
    parameters: [
      status: [
        in: :query,
        schema: IncidentSchemas.IncidentStatus,
        description: "Filter by status"
      ],
      severity: [
        in: :query,
        schema: IncidentSchemas.IncidentSeverity,
        description: "Filter by severity"
      ],
      muted: [
        in: :query,
        schema: %OpenApiSpex.Schema{type: :boolean},
        description: "Filter by muted status"
      ],
      source: [
        in: :query,
        schema: %OpenApiSpex.Schema{type: :string},
        description: "Filter by source"
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
      ok: {"Incident list", "application/json", IncidentSchemas.IncidentListResponse},
      unauthorized: {"Unauthorized", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def index(conn, params) do
    with :ok <- GIWeb.Api.V1.PaginationHelpers.validate_pagination(params) do
      filters = build_filters(params)
      result = Tracking.list_incidents_paginated(conn.assigns.current_account, filters)

      render(conn, :index,
        incidents: result.incidents,
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
    |> maybe_add_filter(:severity, params["severity"])
    |> maybe_add_filter(:source, params["source"])
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
    summary: "Get incident",
    description: "Returns a specific incident by ID with paginated occurrences",
    parameters: [
      id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        description: "Incident ID",
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
      ok: {"Incident with occurrences", "application/json", IncidentSchemas.IncidentResponse},
      not_found: {"Not found", "application/json", GIWeb.ErrorJSON},
      unauthorized: {"Unauthorized", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def show(conn, %{"id" => id} = params) do
    opts = [
      page: params["page"],
      per_page: params["per_page"]
    ]

    case Tracking.get_incident_with_occurrences(conn.assigns.current_account, id, opts) do
      nil -> {:error, :not_found}
      incident -> render(conn, :show, incident: incident)
    end
  end

  operation(:create,
    summary: "Report incident",
    description:
      "Reports an incident. If fingerprint matches existing incident, adds occurrence or reopens. Otherwise creates new issue and incident.",
    request_body: {"Incident params", "application/json", IncidentSchemas.IncidentReportRequest},
    responses: [
      created: {"Incident created", "application/json", IncidentSchemas.IncidentResponse},
      ok: {"Occurrence added", "application/json", IncidentSchemas.IncidentResponse},
      unprocessable_entity: {"Validation error", "application/json", GIWeb.ChangesetJSON},
      unauthorized: {"Unauthorized", "application/json", GIWeb.ErrorJSON},
      forbidden: {"Forbidden", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def create(conn, params) do
    incident_attrs = %{
      fingerprint: params["fingerprint"],
      title: params["title"],
      severity: params["severity"],
      source: params["source"],
      metadata: params["metadata"] || %{},
      reopen_window_hours: params["reopen_window_hours"]
    }

    occurrence_attrs = %{
      context: params["context"] || %{}
    }

    project_id = params["project_id"]

    case Tracking.report_incident(
           conn.assigns.current_account,
           conn.assigns.current_user,
           project_id,
           incident_attrs,
           occurrence_attrs
         ) do
      {:ok, %Incident{} = incident, status} ->
        http_status = if status == :created, do: :created, else: :ok

        conn
        |> put_status(http_status)
        |> render(:show, incident: incident)

      {:error, :project_not_found} ->
        {:error, :not_found}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  operation(:update,
    summary: "Update incident",
    description: "Updates an incident's muted flag. Status changes are rejected.",
    parameters: [
      id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        description: "Incident ID",
        required: true
      ]
    ],
    request_body: {"Incident params", "application/json", IncidentSchemas.IncidentUpdateRequest},
    responses: [
      ok: {"Incident updated", "application/json", IncidentSchemas.IncidentResponse},
      bad_request: {"Status update rejected", "application/json", GIWeb.ErrorJSON},
      not_found: {"Not found", "application/json", GIWeb.ErrorJSON},
      unprocessable_entity: {"Validation error", "application/json", GIWeb.ChangesetJSON},
      unauthorized: {"Unauthorized", "application/json", GIWeb.ErrorJSON},
      forbidden: {"Forbidden", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def update(conn, %{"id" => id} = params) do
    if params["status"] do
      {:error, :bad_request,
       "Status cannot be updated directly. Use POST /api/v1/incidents/:id/resolve."}
    else
      case Tracking.get_incident(conn.assigns.current_account, id) do
        nil ->
          {:error, :not_found}

        incident ->
          attrs = %{}

          attrs =
            if is_boolean(params["muted"]),
              do: Map.put(attrs, :muted, params["muted"]),
              else: attrs

          with {:ok, %Incident{} = incident} <- Tracking.update_incident(incident, attrs) do
            incident = GI.Repo.preload(incident, [:issue, :incident_occurrences], force: true)
            render(conn, :show, incident: incident)
          end
      end
    end
  end

  operation(:resolve,
    summary: "Resolve incident",
    description: "Resolves an incident, archiving the linked issue.",
    parameters: [
      id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        description: "Incident ID",
        required: true
      ]
    ],
    responses: [
      ok: {"Incident resolved", "application/json", IncidentSchemas.IncidentResponse},
      not_found: {"Not found", "application/json", GIWeb.ErrorJSON},
      unauthorized: {"Unauthorized", "application/json", GIWeb.ErrorJSON},
      forbidden: {"Forbidden", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def resolve(conn, %{"id" => id}) do
    case Tracking.get_incident(conn.assigns.current_account, id, preload: [:issue]) do
      nil ->
        {:error, :not_found}

      incident ->
        case Tracking.resolve_incident(incident) do
          {:ok, resolved} ->
            resolved = GI.Repo.preload(resolved, [:issue, :incident_occurrences], force: true)
            render(conn, :show, incident: resolved)

          {:error, :not_found} ->
            {:error, :not_found}
        end
    end
  end
end
