defmodule GI.Test.TelegramClientSuccess do
  @behaviour GI.Notifications.TelegramClient

  @impl true
  def send_message(_bot_token, _chat_id, _text), do: :ok
end

defmodule GI.Test.TelegramClientFailure do
  @behaviour GI.Notifications.TelegramClient

  @impl true
  def send_message(_bot_token, _chat_id, _text), do: {:error, "Telegram API error: 403"}
end
