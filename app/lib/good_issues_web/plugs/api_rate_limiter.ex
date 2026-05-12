defmodule GIWeb.Plugs.ApiRateLimiter do
  @moduledoc """
  ETS-based rate limiter keyed by API key ID and action.

  Configured via options:
  - `:max_requests` — maximum requests in the window (default: 60)
  - `:window_ms` — sliding window in milliseconds (default: 60_000)
  """
  import Plug.Conn

  @default_max 60
  @default_window_ms 60_000
  @table :api_rate_limiter_buckets

  def init(opts) do
    %{
      max_requests: Keyword.get(opts, :max_requests, @default_max),
      window_ms: Keyword.get(opts, :window_ms, @default_window_ms)
    }
  end

  def call(conn, opts) do
    ensure_table()

    case conn.assigns[:current_api_key] do
      nil ->
        conn

      api_key ->
        key = {api_key.id, conn.request_path}
        now = System.monotonic_time(:millisecond)
        window_start = now - opts.window_ms

        case clean_and_count(key, window_start, now, opts.max_requests) do
          :ok ->
            conn

          :rate_limited ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(429, Jason.encode!(%{error: "rate limit exceeded"}))
            |> halt()
        end
    end
  end

  defp ensure_table do
    try do
      :ets.new(@table, [:named_table, :public, :set])
    rescue
      ArgumentError -> :ok
    end
  end

  defp clean_and_count(key, window_start, now, max_requests) do
    case :ets.lookup(@table, key) do
      [{^key, timestamps}] ->
        filtered = Enum.filter(timestamps, &(&1 > window_start))

        if length(filtered) >= max_requests do
          :ets.insert(@table, {key, filtered})
          :rate_limited
        else
          :ets.insert(@table, {key, [now | filtered]})
          :ok
        end

      [] ->
        :ets.insert(@table, {key, [now]})
        :ok
    end
  end
end
