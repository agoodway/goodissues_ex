defmodule FF.Monitoring.HttpClient do
  @moduledoc """
  Behaviour for executing the HTTP request that a check observes.

  Existing implementations:

    * `FF.Monitoring.HttpClient.Req` — production-grade Req-backed client
    * `FF.Monitoring.HttpClient.Mock` — overridable in tests via
      `Application.put_env(:app, FF.Monitoring.Workers.CheckRunner, http_client: ...)`

  The behaviour is intentionally narrow: it takes the same keyword list
  Req accepts and returns either `{:ok, %{status: integer, body: any}}`
  or `{:error, reason}`.
  """

  @callback request(opts :: keyword()) ::
              {:ok, %{status: integer(), body: any()}} | {:error, term()}
end

defmodule FF.Monitoring.HttpClient.Req do
  @moduledoc """
  Default Req-backed HTTP client used by the check worker.
  """

  @behaviour FF.Monitoring.HttpClient

  @impl true
  def request(opts) do
    case Req.request(opts) do
      {:ok, %Req.Response{status: status, body: body}} -> {:ok, %{status: status, body: body}}
      {:error, reason} -> {:error, reason}
    end
  end
end
