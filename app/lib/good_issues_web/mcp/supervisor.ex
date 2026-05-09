defmodule GIWeb.MCP.Supervisor do
  @moduledoc """
  Supervisor for the MCP server subsystem.

  Uses :rest_for_one strategy so that if the MCP server crashes,
  the registry also restarts to clear stale sessions.
  """
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children =
      maybe_start_session_store() ++
        [
          # Registry must start before the server
          Anubis.Server.Registry,

          # Then the MCP server
          {GIWeb.MCP.Server, transport: :streamable_http, name: GIWeb.MCP.Server}
        ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  # Skip starting SessionStore if already running (e.g. started by Tidewave)
  defp maybe_start_session_store do
    case GenServer.whereis(GIWeb.MCP.SessionStore) do
      nil -> [GIWeb.MCP.SessionStore]
      _pid -> []
    end
  end

  @doc "Restart only the MCP server"
  def restart_server do
    Supervisor.terminate_child(__MODULE__, GIWeb.MCP.Server)
    Supervisor.restart_child(__MODULE__, GIWeb.MCP.Server)
  end

  @doc "Restart entire MCP subsystem"
  def restart_all do
    Supervisor.stop(__MODULE__, :normal)
  end
end
