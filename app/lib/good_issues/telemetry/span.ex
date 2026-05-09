defmodule GI.Telemetry.Span do
  @moduledoc """
  Represents a telemetry span captured from a client application.

  Spans capture timing and context information for various events:
  - Phoenix request lifecycle (endpoint start/stop)
  - Router dispatch events (including exceptions)
  - LiveView mount and handle_event exceptions
  - Ecto slow queries

  Spans can be correlated by `request_id` to reconstruct the full
  request lifecycle, including any errors that occurred.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias GI.Tracking.Project

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          project_id: Ecto.UUID.t(),
          request_id: String.t() | nil,
          trace_id: String.t() | nil,
          event_type: atom(),
          event_name: String.t(),
          timestamp: DateTime.t(),
          duration_ms: float() | nil,
          context: map(),
          measurements: map(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @event_types [
    :phoenix_request,
    :phoenix_router,
    :phoenix_error,
    :liveview_mount,
    :liveview_event,
    :ecto_query
  ]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "telemetry_spans" do
    field :request_id, :string
    field :trace_id, :string

    field :event_type, Ecto.Enum, values: @event_types
    field :event_name, :string
    field :timestamp, :utc_datetime_usec
    field :duration_ms, :float
    field :context, :map, default: %{}
    field :measurements, :map, default: %{}

    belongs_to :project, Project

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new span.
  """
  @spec create_changeset(t(), map()) :: Ecto.Changeset.t()
  def create_changeset(span, attrs) do
    span
    |> cast(attrs, [
      :project_id,
      :request_id,
      :trace_id,
      :event_type,
      :event_name,
      :timestamp,
      :duration_ms,
      :context,
      :measurements
    ])
    |> validate_required([:project_id, :event_type, :event_name, :timestamp])
    |> validate_inclusion(:event_type, @event_types)
    |> foreign_key_constraint(:project_id)
  end
end
