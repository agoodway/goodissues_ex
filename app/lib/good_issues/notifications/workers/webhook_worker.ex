defmodule GI.Notifications.Workers.WebhookWorker do
  @moduledoc """
  Oban worker for delivering signed webhook notifications.
  """

  use Oban.Worker,
    queue: :notifications_webhook,
    max_attempts: 10,
    unique: [keys: [:event_id, :destination], period: 60]

  require Logger

  alias GI.Notifications
  alias GI.Notifications.{WebhookPayload, WebhookSigner}

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    %{
      "event_id" => event_id,
      "event_type" => event_type,
      "event_data" => event_data,
      "account_id" => account_id,
      "destination" => destination,
      "subscription_id" => subscription_id,
      "secret" => secret
    } = args

    occurred_at = Map.get(args, "occurred_at", DateTime.utc_now() |> DateTime.to_iso8601())
    resource_type = args["resource_type"]
    resource_id = args["resource_id"]

    msg_id = "msg_" <> event_id
    timestamp = DateTime.utc_now() |> DateTime.to_unix() |> Integer.to_string()
    body = WebhookPayload.build(event_type, event_data, occurred_at)
    signature = WebhookSigner.sign(secret, msg_id, timestamp, body)

    headers = [
      {"content-type", "application/json"},
      {"webhook-id", msg_id},
      {"webhook-timestamp", timestamp},
      {"webhook-signature", signature}
    ]

    case webhook_client().post(destination, headers, body) do
      {:ok, status} when status in 200..299 ->
        log_result(event_type, account_id, subscription_id, destination, "delivered",
          resource_type: resource_type,
          resource_id: resource_id
        )

        :ok

      {:ok, status} ->
        log_result(event_type, account_id, subscription_id, destination, "failed",
          error: "http #{status}",
          resource_type: resource_type,
          resource_id: resource_id
        )

        {:error, {:http_status, status}}

      {:error, reason} ->
        log_result(event_type, account_id, subscription_id, destination, "failed",
          error: inspect(reason),
          resource_type: resource_type,
          resource_id: resource_id
        )

        {:error, reason}
    end
  end

  defp webhook_client do
    Application.get_env(:good_issues, :webhook_client, GI.Notifications.WebhookClient.HTTP)
  end

  defp log_result(event_type, account_id, subscription_id, destination, status, opts) do
    Notifications.log_delivery(%{
      event_type: event_type,
      account_id: account_id,
      subscription_id: subscription_id,
      destination: destination,
      channel: "webhook",
      status: status,
      error: Keyword.get(opts, :error),
      resource_type: Keyword.get(opts, :resource_type),
      resource_id: Keyword.get(opts, :resource_id)
    })
  end
end
