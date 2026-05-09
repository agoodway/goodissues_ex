defmodule GIWeb.Api.V1.EventController do
  @moduledoc """
  Controller for telemetry event batch operations.

  Handles bulk creation of telemetry spans from GoodIssuesReporter clients.
  """

  use GIWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GI.Telemetry

  plug GIWeb.Plugs.ApiAuth, {:require_scope, "events:write"} when action in [:create_batch]

  action_fallback GIWeb.FallbackController

  tags(["Events"])

  operation(:create_batch,
    summary: "Create events batch",
    description:
      "Creates multiple telemetry spans in a single request. Used by GoodIssuesReporter to efficiently send batched telemetry data.",
    request_body:
      {"Events batch", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           events: %OpenApiSpex.Schema{
             type: :array,
             items: %OpenApiSpex.Schema{
               type: :object,
               properties: %{
                 project_id: %OpenApiSpex.Schema{type: :string, format: :uuid},
                 request_id: %OpenApiSpex.Schema{type: :string},
                 trace_id: %OpenApiSpex.Schema{type: :string},
                 event_type: %OpenApiSpex.Schema{
                   type: :string,
                   enum: [
                     "phoenix_request",
                     "phoenix_router",
                     "phoenix_error",
                     "liveview_mount",
                     "liveview_event",
                     "ecto_query"
                   ]
                 },
                 event_name: %OpenApiSpex.Schema{type: :string},
                 timestamp: %OpenApiSpex.Schema{type: :string, format: :"date-time"},
                 duration_ms: %OpenApiSpex.Schema{type: :number},
                 context: %OpenApiSpex.Schema{type: :object},
                 measurements: %OpenApiSpex.Schema{type: :object}
               },
               required: [:project_id, :event_type, :event_name]
             }
           }
         },
         required: [:events]
       }},
    responses: [
      created:
        {"Batch created", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             inserted: %OpenApiSpex.Schema{type: :integer, description: "Number of spans created"},
             errors: %OpenApiSpex.Schema{
               type: :array,
               description:
                 "List of errors for failed project batches (only present if some batches failed)",
               items: %OpenApiSpex.Schema{
                 type: :object,
                 properties: %{
                   project_id: %OpenApiSpex.Schema{type: :string, format: :uuid},
                   error: %OpenApiSpex.Schema{type: :string}
                 }
               }
             }
           }
         }},
      bad_request: {"Bad request", "application/json", GIWeb.ErrorJSON},
      unauthorized: {"Unauthorized", "application/json", GIWeb.ErrorJSON},
      forbidden: {"Forbidden", "application/json", GIWeb.ErrorJSON}
    ]
  )

  @max_batch_size 1000

  @doc """
  Creates multiple telemetry spans from a batch of events.

  Events are grouped by project_id and inserted in bulk for efficiency.
  Maximum batch size is #{@max_batch_size} events.
  """
  def create_batch(conn, %{"events" => events})
      when is_list(events) and length(events) > @max_batch_size do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "batch size exceeds maximum of #{@max_batch_size} events"})
  end

  def create_batch(conn, %{"events" => events}) when is_list(events) do
    account = conn.assigns.current_account

    # Group events by project_id
    events_by_project = Enum.group_by(events, & &1["project_id"])
    all_project_ids = Map.keys(events_by_project)

    # Validate all project IDs in a single query to avoid N+1
    valid_project_ids = Telemetry.validate_project_ids(account, all_project_ids)

    # Process valid and invalid projects
    {valid_batches, invalid_ids} =
      Enum.split_with(all_project_ids, &MapSet.member?(valid_project_ids, &1))

    # Insert spans for valid projects
    insert_results =
      Enum.map(valid_batches, fn project_id ->
        {:ok, count} =
          Telemetry.create_spans_batch_unchecked(project_id, events_by_project[project_id])

        count
      end)

    total_inserted = Enum.sum(insert_results)

    # Build errors for invalid projects
    errors = Enum.map(invalid_ids, &%{project_id: &1, error: :project_not_found})

    if errors == [] do
      conn
      |> put_status(:created)
      |> json(%{inserted: total_inserted})
    else
      conn
      |> put_status(:created)
      |> json(%{inserted: total_inserted, errors: errors})
    end
  end

  def create_batch(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "events must be an array"})
  end
end
