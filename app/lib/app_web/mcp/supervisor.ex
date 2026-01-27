defmodule FFWeb.MCP.Supervisor do
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
    children = [
      # Registry must start first
      Hermes.Server.Registry,

      # Then the MCP server
      {FFWeb.MCP.Server, transport: :streamable_http, name: FFWeb.MCP.Server}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  @doc "Restart only the MCP server"
  def restart_server do
    Supervisor.terminate_child(__MODULE__, FFWeb.MCP.Server)
    Supervisor.restart_child(__MODULE__, FFWeb.MCP.Server)
  end

  @doc "Restart entire MCP subsystem"
  def restart_all do
    Supervisor.stop(__MODULE__, :normal)
  end
end
