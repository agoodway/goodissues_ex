defmodule GI.Telemetry do
  @moduledoc """
  The Telemetry context.

  Manages telemetry spans collected from applications using GoodIssuesReporter.
  Spans capture performance data and request lifecycle information that can be
  correlated with errors via request_id.
  """

  import Ecto.Query

  alias GI.Accounts.Account
  alias GI.Repo
  alias GI.Telemetry.Span
  alias GI.Tracking.Project

  @doc """
  Creates multiple spans in a single bulk insert.

  Accepts a list of span parameter maps and inserts them efficiently
  using `Repo.insert_all/3`.

  ## Parameters

    - `account` - The account the spans belong to
    - `project_id` - The project UUID (validated against account)
    - `events_params` - List of event parameter maps

  ## Returns

    - `{:ok, count}` on success with number of inserted spans
    - `{:error, :project_not_found}` if project doesn't exist or wrong account

  ## Examples

      iex> create_spans_batch(account, project_id, [%{...}, %{...}])
      {:ok, 2}

  """
  @spec create_spans_batch(Account.t(), String.t(), list(map())) ::
          {:ok, non_neg_integer()} | {:error, :project_not_found}
  def create_spans_batch(%Account{} = account, project_id, events_params)
      when is_list(events_params) do
    if project_belongs_to_account?(account, project_id) do
      do_insert_spans(project_id, events_params)
    else
      {:error, :project_not_found}
    end
  end

  @doc """
  Creates multiple spans without ownership validation.

  Use this only when project ownership has already been validated
  via `validate_project_ids/2`.
  """
  @spec create_spans_batch_unchecked(String.t(), list(map())) :: {:ok, non_neg_integer()}
  def create_spans_batch_unchecked(project_id, events_params) when is_list(events_params) do
    do_insert_spans(project_id, events_params)
  end

  defp do_insert_spans(project_id, events_params) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries =
      Enum.map(events_params, fn params ->
        %{
          id: Ecto.UUID.generate(),
          project_id: project_id,
          request_id: params["request_id"],
          trace_id: params["trace_id"],
          event_type: parse_event_type(params["event_type"]),
          event_name: params["event_name"],
          timestamp: parse_timestamp_usec(params["timestamp"]),
          duration_ms: params["duration_ms"],
          context: params["context"] || %{},
          measurements: params["measurements"] || %{},
          inserted_at: now,
          updated_at: now
        }
      end)

    {count, _} = Repo.insert_all(Span, entries)
    {:ok, count}
  end

  @doc """
  Validates which project IDs belong to the given account.

  Returns a MapSet of valid project IDs that belong to the account.
  Invalid UUIDs are silently filtered out.
  """
  @spec validate_project_ids(Account.t(), [String.t()]) :: MapSet.t(String.t())
  def validate_project_ids(%Account{id: account_id}, project_ids) when is_list(project_ids) do
    valid_uuids = Enum.filter(project_ids, &valid_uuid?/1)

    if valid_uuids == [] do
      MapSet.new()
    else
      from(p in Project,
        where: p.id in ^valid_uuids and p.account_id == ^account_id,
        select: p.id
      )
      |> Repo.all()
      |> MapSet.new()
    end
  end

  defp project_belongs_to_account?(%Account{id: account_id}, project_id) do
    valid_uuid?(project_id) and
      Repo.exists?(from(p in Project, where: p.id == ^project_id and p.account_id == ^account_id))
  end

  defp valid_uuid?(string) when is_binary(string) do
    case Ecto.UUID.dump(string) do
      {:ok, _} -> true
      :error -> false
    end
  end

  defp valid_uuid?(_), do: false

  # Map of valid event type strings to atoms, ensuring atoms exist at compile time
  # by referencing GI.Telemetry.Span's event_types
  @event_type_map %{
    "phoenix_request" => :phoenix_request,
    "phoenix_router" => :phoenix_router,
    "phoenix_error" => :phoenix_error,
    "liveview_mount" => :liveview_mount,
    "liveview_event" => :liveview_event,
    "ecto_query" => :ecto_query
  }

  defp parse_event_type(type) when is_map_key(@event_type_map, type) do
    Map.fetch!(@event_type_map, type)
  end

  defp parse_event_type(_), do: :phoenix_request

  # For timestamp field (utc_datetime_usec - requires microseconds)
  defp parse_timestamp_usec(nil), do: DateTime.utc_now()

  defp parse_timestamp_usec(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _offset} -> ensure_usec(dt)
      {:error, _} -> DateTime.utc_now()
    end
  end

  defp parse_timestamp_usec(_), do: DateTime.utc_now()

  # Ensure DateTime has microsecond precision for utc_datetime_usec field
  defp ensure_usec(%DateTime{microsecond: {0, 0}} = dt) do
    %{dt | microsecond: {0, 6}}
  end

  defp ensure_usec(dt), do: dt

  @doc """
  Lists spans for a given request_id.

  Useful for correlating all telemetry events within a single request.

  ## Examples

      iex> list_spans_by_request_id(account, "abc123")
      [%Span{}, ...]

  """
  @spec list_spans_by_request_id(Account.t(), String.t()) :: list(Span.t())
  def list_spans_by_request_id(%Account{id: account_id}, request_id) do
    Span
    |> join(:inner, [s], p in Project, on: s.project_id == p.id)
    |> where([s, p], p.account_id == ^account_id and s.request_id == ^request_id)
    |> order_by([s], asc: s.timestamp)
    |> Repo.all()
  end

  @doc """
  Lists spans for a given request_id, scoped to a specific project.

  Useful for displaying telemetry data on the issue detail page where the
  project is already known.

  ## Examples

      iex> list_spans_by_request_id_for_project(account, project_id, "abc123")
      [%Span{}, ...]

  """
  @spec list_spans_by_request_id_for_project(Account.t(), String.t(), String.t()) ::
          list(Span.t())
  def list_spans_by_request_id_for_project(%Account{id: account_id}, project_id, request_id) do
    if valid_uuid?(project_id) do
      Span
      |> join(:inner, [s], p in Project, on: s.project_id == p.id)
      |> where(
        [s, p],
        p.account_id == ^account_id and s.project_id == ^project_id and
          s.request_id == ^request_id
      )
      |> order_by([s], asc: s.timestamp)
      |> Repo.all()
    else
      []
    end
  end

  @doc """
  Lists recent spans for a project.

  ## Options

    * `:limit` - Maximum number of spans to return (default: 100)
    * `:event_type` - Filter by event type

  """
  @spec list_spans(Account.t(), String.t(), keyword()) :: list(Span.t())
  def list_spans(%Account{id: account_id}, project_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    event_type = Keyword.get(opts, :event_type)

    query =
      Span
      |> join(:inner, [s], p in Project, on: s.project_id == p.id)
      |> where([s, p], p.account_id == ^account_id and s.project_id == ^project_id)
      |> order_by([s], desc: s.timestamp)
      |> limit(^limit)

    query =
      if event_type do
        where(query, [s], s.event_type == ^event_type)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Gets a span by ID, scoped to account.
  """
  @spec get_span(Account.t(), String.t()) :: Span.t() | nil
  def get_span(%Account{id: account_id}, span_id) do
    if valid_uuid?(span_id) do
      Span
      |> join(:inner, [s], p in Project, on: s.project_id == p.id)
      |> where([s, p], s.id == ^span_id and p.account_id == ^account_id)
      |> Repo.one()
    else
      nil
    end
  end
end
