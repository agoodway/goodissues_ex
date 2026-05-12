defmodule GI.Notifications.TelegramClient do
  @moduledoc """
  Behaviour for sending Telegram Bot API messages.
  """

  @callback send_message(bot_token :: String.t(), chat_id :: String.t(), text :: String.t()) ::
              :ok | {:error, term()}
end
