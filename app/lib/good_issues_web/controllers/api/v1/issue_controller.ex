defmodule FFWeb.Api.V1.IssueController do
  use FFWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias FF.Tracking
  alias FF.Tracking.Issue
  alias FFWeb.Api.V1.Schemas.Issue, as: IssueSchemas

  plug FFWeb.Plugs.ApiAuth, {:require_scope, "issues:read"} when action in [:index, :show]

  plug FFWeb.Plugs.ApiAuth,
       {:require_scope, "issues:write"} when action in [:create, :update, :delete]

  action_fallback FFWeb.FallbackController

  tags(["Issues"])

  operation(:index,
    summary: "List issues",
    description: "Returns all issues for the authenticated user's account",
    parameters: [
      project_id: [
        in: :query,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        description: "Filter by project ID"
      ],
      status: [
        in: :query,
        schema: IssueSchemas.IssueStatus,
        description: "Filter by status"
      ],
      type: [
        in: :query,
        schema: IssueSchemas.IssueType,
        description: "Filter by type"
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
      ok: {"Issue list", "application/json", IssueSchemas.IssueListResponse},
      bad_request: {"Bad request", "application/json", FFWeb.ErrorJSON},
      unauthorized: {"Unauthorized", "application/json", FFWeb.ErrorJSON}
    ]
  )

  def index(conn, params) do
    with :ok <- FFWeb.Api.V1.PaginationHelpers.validate_pagination(params) do
      filters = build_filters(params)
      result = Tracking.list_issues_paginated(conn.assigns.current_account, filters)

      render(conn, :index,
        issues: result.issues,
        page: result.page,
        per_page: result.per_page,
        total: result.total,
        total_pages: result.total_pages
      )
    end
  end

  defp build_filters(params) do
    %{}
    |> maybe_add_filter(:project_id, params["project_id"])
    |> maybe_add_filter(:status, params["status"])
    |> maybe_add_filter(:type, params["type"])
    |> maybe_add_filter(:page, params["page"])
    |> maybe_add_filter(:per_page, params["per_page"])
  end

  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, _key, ""), do: filters
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)

  operation(:show,
    summary: "Get issue",
    description: "Returns a specific issue by ID",
    parameters: [
      id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        description: "Issue ID",
        required: true
      ]
    ],
    responses: [
      ok: {"Issue", "application/json", IssueSchemas.IssueResponse},
      not_found: {"Not found", "application/json", FFWeb.ErrorJSON},
      unauthorized: {"Unauthorized", "application/json", FFWeb.ErrorJSON}
    ]
  )

  def show(conn, %{"id" => id}) do
    case Tracking.get_issue(conn.assigns.current_account, id, preload: [:project]) do
      nil -> {:error, :not_found}
      issue -> render(conn, :show, issue: issue)
    end
  end

  operation(:create,
    summary: "Create issue",
    description: "Creates a new issue in a project",
    request_body: {"Issue params", "application/json", IssueSchemas.IssueRequest},
    responses: [
      created: {"Issue created", "application/json", IssueSchemas.IssueResponse},
      unprocessable_entity: {"Validation error", "application/json", FFWeb.ChangesetJSON},
      unauthorized: {"Unauthorized", "application/json", FFWeb.ErrorJSON},
      forbidden: {"Forbidden", "application/json", FFWeb.ErrorJSON}
    ]
  )

  def create(conn, params) do
    with {:ok, %Issue{} = issue} <-
           Tracking.create_issue(
             conn.assigns.current_account,
             conn.assigns.current_user,
             params
           ) do
      # Preload project for key computation
      issue = FF.Repo.preload(issue, :project)

      conn
      |> put_status(:created)
      |> render(:show, issue: issue)
    end
  end

  operation(:update,
    summary: "Update issue",
    description: "Updates an existing issue",
    parameters: [
      id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        description: "Issue ID",
        required: true
      ]
    ],
    request_body: {"Issue params", "application/json", IssueSchemas.IssueUpdateRequest},
    responses: [
      ok: {"Issue updated", "application/json", IssueSchemas.IssueResponse},
      not_found: {"Not found", "application/json", FFWeb.ErrorJSON},
      unprocessable_entity: {"Validation error", "application/json", FFWeb.ChangesetJSON},
      unauthorized: {"Unauthorized", "application/json", FFWeb.ErrorJSON},
      forbidden: {"Forbidden", "application/json", FFWeb.ErrorJSON}
    ]
  )

  def update(conn, %{"id" => id} = params) do
    case Tracking.get_issue(conn.assigns.current_account, id) do
      nil ->
        {:error, :not_found}

      issue ->
        with {:ok, %Issue{} = issue} <- Tracking.update_issue(issue, params) do
          # Preload project for key computation
          issue = FF.Repo.preload(issue, :project)
          render(conn, :show, issue: issue)
        end
    end
  end

  operation(:delete,
    summary: "Delete issue",
    description: "Deletes an issue",
    parameters: [
      id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        description: "Issue ID",
        required: true
      ]
    ],
    responses: [
      no_content: "Issue deleted",
      not_found: {"Not found", "application/json", FFWeb.ErrorJSON},
      unauthorized: {"Unauthorized", "application/json", FFWeb.ErrorJSON},
      forbidden: {"Forbidden", "application/json", FFWeb.ErrorJSON}
    ]
  )

  def delete(conn, %{"id" => id}) do
    case Tracking.get_issue(conn.assigns.current_account, id) do
      nil ->
        {:error, :not_found}

      issue ->
        with {:ok, %Issue{}} <- Tracking.delete_issue(issue) do
          send_resp(conn, :no_content, "")
        end
    end
  end
end
