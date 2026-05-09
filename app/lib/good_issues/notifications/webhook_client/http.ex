defmodule FF.Notifications.WebhookClient.HTTP do
  @moduledoc """
  Req-based webhook delivery implementation.
  """

  @behaviour FF.Notifications.WebhookClient

  @request_timeout_ms 20_000

  @impl true
  @spec post(String.t(), [{String.t(), String.t()}], String.t()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def post(url, headers, body) do
    case Req.post(url,
           headers: headers,
           body: body,
           redirect: false,
           receive_timeout: @request_timeout_ms
         ) do
      {:ok, %Req.Response{status: status}} -> {:ok, status}
      {:error, exception} -> {:error, exception}
    end
  end
end
