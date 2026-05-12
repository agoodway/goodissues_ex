defmodule GI.Notifications.TelegramClient.HTTP do
  @moduledoc """
  Req-based Telegram Bot API implementation.
  """

  @behaviour GI.Notifications.TelegramClient

  @base_url "https://api.telegram.org"
  @request_timeout_ms 20_000

  @impl true
  def send_message(bot_token, chat_id, text) do
    url = "#{@base_url}/bot#{bot_token}/sendMessage"

    body =
      Jason.encode!(%{
        chat_id: chat_id,
        text: text,
        parse_mode: "MarkdownV2",
        link_preview_options: %{is_disabled: true}
      })

    case Req.post(url,
           headers: [{"content-type", "application/json"}],
           body: body,
           redirect: false,
           receive_timeout: @request_timeout_ms
         ) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "Telegram API error: #{status} - #{inspect(body)}"}

      {:error, exception} ->
        {:error, exception}
    end
  end
end
