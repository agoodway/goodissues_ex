defmodule GI.Notifications.WebhookPayload do
  @moduledoc """
  Builds Standard Webhooks JSON payloads.
  """

  @spec build(String.t(), map(), DateTime.t() | NaiveDateTime.t() | String.t()) :: String.t()
  def build(event_type, event_data, occurred_at) do
    %{
      "type" => String.replace(event_type, "_", "."),
      "timestamp" => to_iso8601(occurred_at),
      "data" => event_data
    }
    |> Jason.encode!()
  end

  defp to_iso8601(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp to_iso8601(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt) <> "Z"
  defp to_iso8601(value) when is_binary(value), do: value
end
