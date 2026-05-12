defmodule GI.Notifications.Workers.TelegramWorker do
  @moduledoc """
  Oban worker for delivering Telegram notifications.
  """

  use Oban.Worker,
    queue: :notifications_telegram,
    max_attempts: 5,
    unique: [keys: [:event_id, :destination], period: 60]

  require Logger

  alias GI.Notifications
  alias GI.Notifications.TelegramMessages
  alias GI.TelegramProfiles

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    %{
      "event_type" => event_type,
      "event_data" => event_data,
      "account_id" => account_id,
      "destination" => destination,
      "subscription_id" => subscription_id
    } = args

    resource_type = args["resource_type"]
    resource_id = args["resource_id"]

    with :ok <- validate_chat_id(destination),
         {:ok, profile} <- load_profile(account_id),
         message <- TelegramMessages.build(event_type, event_data),
         :ok <- telegram_client().send_message(profile.bot_token_encrypted, destination, message) do
      log_result(event_type, account_id, subscription_id, destination, "delivered",
        resource_type: resource_type,
        resource_id: resource_id
      )

      :ok
    else
      {:cancel, reason} = cancel ->
        log_result(event_type, account_id, subscription_id, destination, "failed",
          error: reason,
          resource_type: resource_type,
          resource_id: resource_id
        )

        cancel

      {:error, reason} = error ->
        log_result(event_type, account_id, subscription_id, destination, "failed",
          error: inspect(reason),
          resource_type: resource_type,
          resource_id: resource_id
        )

        error
    end
  end

  defp validate_chat_id(destination) do
    if Regex.match?(~r/^-?\d+$/, destination) do
      :ok
    else
      {:cancel, "invalid Telegram chat ID: #{destination}"}
    end
  end

  defp load_profile(account_id) do
    case TelegramProfiles.get_by_account(account_id) do
      nil -> {:cancel, "no Telegram profile for account #{account_id}"}
      profile -> {:ok, profile}
    end
  end

  defp telegram_client do
    Application.get_env(:good_issues, :telegram_client, GI.Notifications.TelegramClient.HTTP)
  end

  defp log_result(event_type, account_id, subscription_id, destination, status, opts) do
    Notifications.log_delivery(%{
      event_type: event_type,
      account_id: account_id,
      subscription_id: subscription_id,
      destination: destination,
      channel: "telegram",
      status: status,
      error: Keyword.get(opts, :error),
      resource_type: Keyword.get(opts, :resource_type),
      resource_id: Keyword.get(opts, :resource_id)
    })
  end
end
