defmodule GI.Notifications.Listener do
  @moduledoc """
  GenServer that subscribes to the global notifications PubSub topic
  and orchestrates delivery by enqueuing Oban workers for each
  matching subscription.
  """

  use GenServer

  require Logger

  alias GI.Notifications
  alias GI.Notifications.Event
  alias GI.Notifications.Workers.{EmailWorker, WebhookWorker}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    Phoenix.PubSub.subscribe(GI.PubSub, "notifications")
    {:ok, %{}}
  end

  @impl GenServer
  def handle_info(%Event{} = event, state) do
    subscriptions = resolve_matching_subscriptions(event)
    Enum.each(subscriptions, &enqueue_delivery(event, &1))
    {:noreply, state}
  rescue
    error ->
      Logger.error(
        "Listener failed to process event #{event.type}: #{inspect(error)}\n#{Exception.format_stacktrace(__STACKTRACE__)}"
      )

      {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp resolve_matching_subscriptions(%Event{} = event) do
    event_type = Atom.to_string(event.type)
    Notifications.resolve_subscriptions(event_type, event.account_id)
  end

  defp enqueue_delivery(%Event{} = event, subscription) do
    {resource_type, resource_id} = resource_for_event(event)

    job_args = %{
      event_id: event.event_id,
      event_type: Atom.to_string(event.type),
      event_data: event.data,
      account_id: event.account_id,
      destination: subscription.destination,
      subscription_id: subscription.id,
      occurred_at: DateTime.to_iso8601(event.occurred_at),
      resource_type: resource_type,
      resource_id: resource_id,
      secret: subscription.secret
    }

    result =
      case subscription.channel do
        "email" -> EmailWorker.new(job_args) |> Oban.insert()
        "webhook" -> WebhookWorker.new(job_args) |> Oban.insert()
        other -> {:error, "Unknown channel: #{other}"}
      end

    case result do
      {:ok, _job} ->
        :ok

      {:error, reason} ->
        Logger.error(
          "Failed to enqueue #{subscription.channel} delivery for event #{event.event_id}: #{inspect(reason)}"
        )

        :ok
    end
  end

  defp resource_for_event(%Event{type: type, data: data}) do
    case type do
      t when t in [:issue_created, :issue_updated, :issue_status_changed] ->
        {"issue", data[:issue_id] || data["issue_id"]}

      t when t in [:error_occurred, :error_resolved] ->
        {"error", data[:error_id] || data["error_id"]}

      _ ->
        {nil, nil}
    end
  end
end
