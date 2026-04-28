defmodule FF.Notifications.WebhookClient do
  @moduledoc """
  Behaviour for delivering webhook HTTP requests.
  """

  @callback post(String.t(), [{String.t(), String.t()}], String.t()) ::
              {:ok, non_neg_integer()} | {:error, term()}
end
