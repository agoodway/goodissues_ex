defmodule FF.Notifications.Workers.EmailWorker do
  @moduledoc """
  Oban worker for delivering email notifications.

  Unique on `event_id` + `destination` to prevent duplicate delivery
  within a 60-second window.
  """

  use Oban.Worker,
    queue: :notifications_email,
    max_attempts: 5,
    unique: [keys: [:event_id, :destination], period: 60]

  require Logger
  import Swoosh.Email

  alias FF.Notifications

  @email_regex ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    %{
      "event_type" => event_type,
      "event_data" => event_data,
      "destination" => destination,
      "account_id" => account_id,
      "subscription_id" => subscription_id
    } = args

    resource_type = args["resource_type"]
    resource_id = args["resource_id"]

    if Regex.match?(@email_regex, destination) do
      email =
        new()
        |> to(destination)
        |> from(mail_from())
        |> subject("[FruitFly] #{humanize_event(event_type)}")
        |> text_body(build_text_body(event_type, event_data))

      case FF.Mailer.deliver(email) do
        {:ok, _} ->
          log_result(event_type, account_id, subscription_id, destination, "delivered",
            resource_type: resource_type,
            resource_id: resource_id
          )

          :ok

        {:error, reason} ->
          error_msg = inspect(reason) |> String.slice(0, 500)

          log_result(event_type, account_id, subscription_id, destination, "failed",
            error: error_msg,
            resource_type: resource_type,
            resource_id: resource_id
          )

          {:error, reason}
      end
    else
      log_result(event_type, account_id, subscription_id, destination, "failed",
        error: "invalid email",
        resource_type: resource_type,
        resource_id: resource_id
      )

      {:cancel, "Invalid email destination: #{destination}"}
    end
  end

  defp mail_from do
    {"FruitFly", "notifications@fruitfly.dev"}
  end

  defp humanize_event(event_type) do
    event_type
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp build_text_body(event_type, event_data) do
    "Event: #{humanize_event(event_type)}\n\n" <>
      Enum.map_join(event_data, "\n", fn {k, v} -> "#{k}: #{inspect(v)}" end)
  end

  defp log_result(event_type, account_id, subscription_id, destination, status, opts) do
    Notifications.log_delivery(%{
      event_type: event_type,
      account_id: account_id,
      subscription_id: subscription_id,
      destination: destination,
      channel: "email",
      status: status,
      error: Keyword.get(opts, :error),
      resource_type: Keyword.get(opts, :resource_type),
      resource_id: Keyword.get(opts, :resource_id)
    })
  end
end
