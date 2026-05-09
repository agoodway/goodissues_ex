defmodule GI.Notifications.EventSubscription do
  @moduledoc """
  Schema for event subscriptions that declare who receives which events.

  Each subscription configures:
  - **event_types**: which events to receive
  - **channel**: delivery channel — `"email"` or `"webhook"`
  - **destination**: static address (mutually exclusive with `user_id`)
  - **user_id**: resolves to user's email at delivery time
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias GI.Accounts.{Account, User}
  alias GI.Notifications.Event
  alias GI.Notifications.WebhookSigner

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          event_types: [String.t()],
          channel: String.t() | nil,
          destination: String.t() | nil,
          criteria: String.t() | nil,
          secret: String.t() | nil,
          active: boolean(),
          name: String.t() | nil,
          account_id: Ecto.UUID.t() | nil,
          user_id: Ecto.UUID.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @channels ~w(email webhook)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "event_subscriptions" do
    field :event_types, {:array, :string}, default: []
    field :channel, :string
    field :destination, :string
    field :criteria, :string
    field :secret, :string
    field :active, :boolean, default: false
    field :name, :string

    belongs_to :account, Account
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [
      :event_types,
      :channel,
      :destination,
      :criteria,
      :active,
      :name,
      :account_id,
      :user_id
    ])
    |> validate_required([:account_id, :channel, :name])
    |> validate_inclusion(:channel, @channels)
    |> validate_event_types()
    |> validate_destination_or_user()
    |> validate_webhook_settings()
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:user_id)
    |> check_constraint(:channel, name: :event_subscriptions_channel_check)
    |> unique_constraint([:account_id, :channel, :destination],
      name: :event_subscriptions_static_destination_index
    )
    |> unique_constraint([:account_id, :channel, :user_id],
      name: :event_subscriptions_user_linked_index
    )
  end

  @spec update_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:event_types, :active, :name, :destination, :user_id, :criteria])
    |> validate_required([:name])
    |> validate_event_types()
    |> validate_destination_or_user()
    |> validate_webhook_settings()
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:account_id, :channel, :destination],
      name: :event_subscriptions_static_destination_index
    )
    |> unique_constraint([:account_id, :channel, :user_id],
      name: :event_subscriptions_user_linked_index
    )
  end

  @valid_event_types Enum.map(Event.event_types(), &Atom.to_string/1)

  defp validate_event_types(changeset) do
    event_types = get_field(changeset, :event_types)

    cond do
      is_nil(event_types) or event_types == [] ->
        add_error(changeset, :event_types, "must have at least one event type")

      invalid = Enum.find(event_types, &(&1 not in @valid_event_types)) ->
        add_error(changeset, :event_types, "contains invalid event type: #{invalid}")

      true ->
        changeset
    end
  end

  defp validate_destination_or_user(changeset) do
    destination = get_field(changeset, :destination)
    user_id = get_field(changeset, :user_id)

    case {destination, user_id} do
      {nil, nil} ->
        add_error(changeset, :destination, "either destination or user_id must be set")

      {dest, uid} when not is_nil(dest) and not is_nil(uid) ->
        add_error(changeset, :destination, "cannot set both destination and user_id")

      _ ->
        changeset
    end
  end

  defp validate_webhook_settings(changeset) do
    if get_field(changeset, :channel) == "webhook" do
      changeset
      |> validate_webhook_destination()
      |> validate_webhook_user()
      |> maybe_put_webhook_secret()
    else
      changeset
    end
  end

  defp validate_webhook_destination(changeset) do
    destination = get_field(changeset, :destination)

    cond do
      is_nil(destination) ->
        add_error(changeset, :destination, "must be set for webhook subscriptions")

      valid_webhook_destination?(destination) ->
        changeset

      true ->
        add_error(
          changeset,
          :destination,
          "must use https:// (http://localhost allowed in dev/test)"
        )
    end
  end

  defp validate_webhook_user(changeset) do
    if is_nil(get_field(changeset, :user_id)) do
      changeset
    else
      add_error(changeset, :user_id, "must be blank for webhook subscriptions")
    end
  end

  defp maybe_put_webhook_secret(changeset) do
    secret = get_field(changeset, :secret)

    if is_binary(secret) and secret != "" do
      changeset
    else
      put_change(changeset, :secret, WebhookSigner.generate_secret())
    end
  end

  defp valid_webhook_destination?(destination) do
    String.starts_with?(destination, "https://") or
      (Application.get_env(:good_issues, :env) in [:dev, :test] and
         String.starts_with?(destination, "http://localhost"))
  end
end
