defmodule GI.Notifications.Event do
  @moduledoc """
  Standard struct for all business events broadcast via the event bus.

  Every event has a unique `event_id` (UUID v4), a `type` atom identifying
  the business event, an `account_id` for tenant scoping, a `data` map with
  event-specific payload, and an `occurred_at` UTC datetime.
  """

  @event_types ~w(
    issue_created
    issue_updated
    issue_status_changed
    error_occurred
    error_resolved
  )a

  @type t :: %__MODULE__{
          event_id: String.t(),
          type: atom(),
          account_id: String.t(),
          data: map(),
          occurred_at: DateTime.t()
        }

  @enforce_keys [:event_id, :type, :account_id, :data, :occurred_at]
  defstruct [:event_id, :type, :account_id, :data, :occurred_at]

  @spec event_types :: [atom()]
  def event_types, do: @event_types

  @spec new(atom(), String.t(), map(), keyword()) :: t()
  def new(type, account_id, data, opts \\ []) when type in @event_types do
    struct!(__MODULE__,
      event_id: Ecto.UUID.generate(),
      type: type,
      account_id: account_id,
      data: Map.merge(data, Map.new(opts)),
      occurred_at: DateTime.utc_now()
    )
  end
end
