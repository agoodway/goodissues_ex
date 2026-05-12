defmodule GI.Notifications.NotificationLog do
  @moduledoc """
  Append-only audit log for notification delivery attempts.

  Records every delivery attempt with its status (pending/delivered/failed),
  the destination, channel, and any error details.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias GI.Accounts.Account
  alias GI.Notifications.EventSubscription

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          event_type: String.t() | nil,
          account_id: Ecto.UUID.t() | nil,
          subscription_id: Ecto.UUID.t() | nil,
          destination: String.t() | nil,
          channel: String.t() | nil,
          status: String.t() | nil,
          error: String.t() | nil,
          resource_type: String.t() | nil,
          resource_id: Ecto.UUID.t() | nil,
          inserted_at: DateTime.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "notification_logs" do
    field :event_type, :string
    field :destination, :string
    field :channel, :string
    field :status, :string
    field :error, :string
    field :resource_type, :string
    field :resource_id, :binary_id

    belongs_to :account, Account
    belongs_to :subscription, EventSubscription

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @required_fields ~w(event_type account_id destination channel status)a
  @optional_fields ~w(subscription_id error resource_type resource_id)a

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = log, attrs) do
    log
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, ~w(pending delivered failed))
    |> validate_inclusion(:channel, ~w(email webhook telegram))
  end
end
