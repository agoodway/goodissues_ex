defmodule GIWeb.MCP.SessionStore do
  @moduledoc """
  ETS-based session store for MCP server.

  Auto-initializes sessions to handle clients (like Claude Code)
  that skip the MCP initialization sequence.
  """
  use GenServer
  @behaviour Anubis.Server.Session.Store

  @table_name :mcp_sessions
  @default_ttl :timer.minutes(30)
  # Limit concurrent sessions to prevent memory exhaustion
  @max_sessions 10_000

  # GenServer callbacks

  @impl GenServer
  def init(_opts) do
    # Use existing table if it exists (handles supervisor restart scenarios)
    # Table is :public because Anubis callbacks are invoked from external processes
    table =
      case :ets.whereis(@table_name) do
        :undefined ->
          :ets.new(@table_name, [:named_table, :public, :set])

        existing ->
          existing
      end

    schedule_cleanup()
    {:ok, %{table: table}}
  end

  # Session Store callbacks

  @impl Anubis.Server.Session.Store
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Anubis.Server.Session.Store
  def save(session_id, state, _opts \\ []) do
    # Check if session already exists (update) or if we're within limits (new)
    existing = :ets.lookup(@table_name, session_id)
    session_count = :ets.info(@table_name, :size)

    if existing != [] or session_count < @max_sessions do
      expires_at = System.monotonic_time(:millisecond) + @default_ttl
      :ets.insert(@table_name, {session_id, state, expires_at})
      :ok
    else
      {:error, :session_limit_exceeded}
    end
  end

  @impl Anubis.Server.Session.Store
  def load(session_id, _opts \\ []) do
    case :ets.lookup(@table_name, session_id) do
      [{^session_id, state, expires_at}] ->
        now = System.monotonic_time(:millisecond)

        if now < expires_at do
          {:ok, Map.put(state, :initialized, true)}
        else
          :ets.delete(@table_name, session_id)
          {:error, :expired}
        end

      [] ->
        # Return pre-initialized session for new session IDs
        # This handles clients that skip the initialization sequence
        {:ok,
         %{
           id: session_id,
           initialized: true,
           log_level: "info",
           protocol_version: "2025-03-26",
           client_info: %{},
           client_capabilities: %{},
           pending_requests: %{}
         }}
    end
  end

  @impl Anubis.Server.Session.Store
  def delete(session_id, _opts \\ []) do
    :ets.delete(@table_name, session_id)
    :ok
  end

  @impl Anubis.Server.Session.Store
  def list_active(_opts \\ []) do
    now = System.monotonic_time(:millisecond)

    sessions =
      :ets.tab2list(@table_name)
      |> Enum.filter(fn {_id, _state, expires_at} -> now < expires_at end)
      |> Enum.map(fn {id, _state, _expires_at} -> id end)

    {:ok, sessions}
  end

  @impl Anubis.Server.Session.Store
  def update_ttl(session_id, ttl_ms, _opts \\ []) do
    case :ets.lookup(@table_name, session_id) do
      [{^session_id, state, _old_expires}] ->
        expires_at = System.monotonic_time(:millisecond) + ttl_ms
        :ets.insert(@table_name, {session_id, state, expires_at})
        :ok

      [] ->
        {:error, :not_found}
    end
  end

  @impl Anubis.Server.Session.Store
  def update(session_id, updates, _opts \\ []) do
    case :ets.lookup(@table_name, session_id) do
      [{^session_id, state, expires_at}] ->
        new_state = Map.merge(state, updates)
        :ets.insert(@table_name, {session_id, new_state, expires_at})
        :ok

      [] ->
        {:error, :not_found}
    end
  end

  @impl Anubis.Server.Session.Store
  def cleanup_expired(_opts \\ []) do
    now = System.monotonic_time(:millisecond)

    expired =
      :ets.tab2list(@table_name)
      |> Enum.filter(fn {_id, _state, expires_at} -> now >= expires_at end)

    Enum.each(expired, fn {id, _state, _expires_at} ->
      :ets.delete(@table_name, id)
    end)

    {:ok, length(expired)}
  end

  @impl GenServer
  def handle_info(:cleanup, state) do
    cleanup_expired([])
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, :timer.minutes(5))
  end
end
