defmodule FF.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # MCP Server - only in dev
    children =
      [
        FFWeb.Telemetry,
        FF.Repo,
        {DNSCluster, query: Application.get_env(:app, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: FF.PubSub}
        # Start a worker by calling: FF.Worker.start_link(arg)
        # {FF.Worker, arg},
      ] ++
        if(Application.get_env(:app, :dev_routes), do: [FFWeb.MCP.Supervisor], else: []) ++
        [
          # Start to serve requests, typically the last entry
          FFWeb.Endpoint
        ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FF.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FFWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
