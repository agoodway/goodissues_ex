defmodule FFWeb.Plugs.RateLimiter do
  @moduledoc """
  Simple ETS-based rate limiter plug keyed by {remote_ip, path_token}.

  Configured via options:
  - `:max_requests` — maximum requests in the window (default: 60)
  - `:window_ms` — sliding window in milliseconds (default: 60_000)
  """
  import Plug.Conn

  @default_max 60
  @default_window_ms 60_000
  @table :rate_limiter_buckets

  def init(opts) do
    %{
      max_requests: Keyword.get(opts, :max_requests, @default_max),
      window_ms: Keyword.get(opts, :window_ms, @default_window_ms)
    }
  end

  def call(conn, opts) do
    ensure_table()

    key = rate_limit_key(conn)
    now = System.monotonic_time(:millisecond)
    window_start = now - opts.window_ms

    # Clean old entries and count current
    clean_and_count(key, window_start, now, opts.max_requests)
    |> case do
      :ok ->
        conn

      :rate_limited ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(429, Jason.encode!(%{error: "rate limit exceeded"}))
        |> halt()
    end
  end

  defp rate_limit_key(conn) do
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()
    token = conn.path_params["heartbeat_token"] || "unknown"
    {ip, token}
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
