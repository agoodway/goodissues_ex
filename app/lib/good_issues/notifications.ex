defmodule GI.Notifications do
  @moduledoc """
  Event bus and subscription management for business event notifications.

  Provides `emit/1` to broadcast events and subscription CRUD for
  managing who receives which events via which channels.
  """

  require Logger
  import Ecto.Query

  alias GI.Notifications.{Event, EventSubscription, NotificationLog}
  alias GI.Repo

  @topic_prefix "notifications:account:"
  @global_topic "notifications"

  # -- Event Bus --------------------------------------------------------------

  @spec subscribe(String.t()) :: :ok | {:error, term()}
  def subscribe(account_id) when is_binary(account_id) do
    Phoenix.PubSub.subscribe(GI.PubSub, topic(account_id))
  end

  @spec topic(String.t()) :: String.t()
  def topic(account_id) when is_binary(account_id) do
    @topic_prefix <> account_id
  end

  @spec emit(Event.t()) :: :ok
  def emit(%Event{} = event) do
    pubsub = GI.PubSub
    Phoenix.PubSub.broadcast(pubsub, topic(event.account_id), event)
    Phoenix.PubSub.local_broadcast(pubsub, @global_topic, event)
    :ok
  rescue
    error ->
      Logger.error("Failed to emit event #{event.type}: #{inspect(error)}")
      :ok
  end

  # -- Subscription Resolution ------------------------------------------------

  @spec resolve_subscriptions(String.t(), String.t()) :: [EventSubscription.t()]
  def resolve_subscriptions(event_type, account_id) do
    from(s in EventSubscription,
      where: s.account_id == ^account_id,
      where: s.active == true,
      where: ^event_type in s.event_types,
      preload: [:user]
    )
    |> Repo.all()
    |> Enum.map(&resolve_destination/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(&{&1.destination, &1.channel})
  end

  defp resolve_destination(%EventSubscription{user_id: nil} = sub), do: sub

  defp resolve_destination(%EventSubscription{user: user, channel: "email"} = sub) do
    if user.email, do: %{sub | destination: user.email}, else: nil
  end

  defp resolve_destination(_sub), do: nil

  # -- Delivery Logging -------------------------------------------------------

  @spec log_delivery(map()) :: {:ok, NotificationLog.t()} | {:error, Ecto.Changeset.t()}
  def log_delivery(attrs) do
    %NotificationLog{}
    |> NotificationLog.changeset(attrs)
    |> Repo.insert()
  end

  @spec list_notification_logs(keyword()) :: [NotificationLog.t()]
  def list_notification_logs(opts \\ []) do
    account_id = Keyword.fetch!(opts, :account_id)
    page = max(Keyword.get(opts, :page, 1), 1)
    page_size = min(Keyword.get(opts, :page_size, 25), 100)

    from(l in NotificationLog,
      where: l.account_id == ^account_id,
      order_by: [desc: l.inserted_at],
      limit: ^page_size,
      offset: ^((page - 1) * page_size)
    )
    |> Repo.all()
  end

  # -- Subscription CRUD ------------------------------------------------------

  @spec list_subscriptions(keyword()) :: [EventSubscription.t()]
  def list_subscriptions(opts \\ []) do
    account_id = Keyword.fetch!(opts, :account_id)

    from(s in EventSubscription,
      where: s.account_id == ^account_id,
      order_by: [desc: s.inserted_at],
      preload: [:user]
    )
    |> Repo.all()
  end

  @spec get_subscription(String.t(), String.t()) ::
          {:ok, EventSubscription.t()} | {:error, :not_found}
  def get_subscription(id, account_id) do
    query =
      from(s in EventSubscription,
        where: s.id == ^id and s.account_id == ^account_id,
        preload: [:user]
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      sub -> {:ok, sub}
    end
  end

  @spec create_subscription(map()) ::
          {:ok, EventSubscription.t()} | {:error, Ecto.Changeset.t()}
  def create_subscription(attrs) do
    %EventSubscription{}
    |> EventSubscription.changeset(attrs)
    |> Repo.insert()
  end

  @spec update_subscription(EventSubscription.t(), map()) ::
          {:ok, EventSubscription.t()} | {:error, Ecto.Changeset.t()}
  def update_subscription(%EventSubscription{} = subscription, attrs) do
    subscription
    |> EventSubscription.update_changeset(attrs)
    |> Repo.update()
  end

  @spec delete_subscription(EventSubscription.t()) ::
          {:ok, EventSubscription.t()} | {:error, Ecto.Changeset.t()}
  def delete_subscription(%EventSubscription{} = subscription) do
    Repo.delete(subscription)
  end

  @spec change_subscription(EventSubscription.t(), map()) :: Ecto.Changeset.t()
  def change_subscription(%EventSubscription{} = subscription, attrs \\ %{}) do
    EventSubscription.changeset(subscription, attrs)
  end
end
