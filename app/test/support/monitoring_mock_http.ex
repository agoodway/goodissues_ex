defmodule GI.MonitoringMockHTTP do
  @moduledoc """
  Test stub for `GI.Monitoring.HttpClient`.

  Set the next response with `set_response/1` (or `set_responses/1` for
  a sequence). Each call to `request/1` consumes the next response. If
  the queue runs dry, returns `{:error, :no_response_configured}`.
  """

  @behaviour GI.Monitoring.HttpClient

  @key :ff_monitoring_mock_http_responses
  @fn_key :ff_monitoring_mock_http_fn

  def set_response(response) do
    set_responses([response])
  end

  def set_responses(list) when is_list(list) do
    Process.put(@key, list)
    :ok
  end

  def set_global_response(response) do
    :persistent_term.put({@key, :global}, [response])
    :ok
  end

  def reset do
    Process.delete(@key)
    Process.delete(@fn_key)
    :persistent_term.erase({@key, :global})
    :ok
  end

  def set_response_fn(fun) when is_function(fun, 1) do
    Process.put(@fn_key, fun)
    :ok
  end

  @impl GI.Monitoring.HttpClient
  def request(opts) do
    case Process.get(@fn_key) do
      fun when is_function(fun, 1) ->
        Process.delete(@fn_key)
        fun.(opts)

      _ ->
        consume_response()
    end
  end

  defp consume_response do
    case process_responses() do
      [response | rest] ->
        Process.put(@key, rest)
        response

      [] ->
        case global_responses() do
          [response | _rest] -> response
          [] -> {:error, :no_response_configured}
        end
    end
  end

  defp process_responses do
    Process.get(@key, [])
  end

  defp global_responses do
    case :persistent_term.get({@key, :global}, []) do
      list when is_list(list) -> list
      _ -> []
    end
  end
end
