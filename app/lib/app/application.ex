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
        {Phoenix.PubSub, name: FF.PubSub},
        {Oban, Application.fetch_env!(:app, Oban)}
      ] ++
        if(Application.get_env(:app, :dev_routes), do: [FFWeb.MCP.Supervisor], else: []) ++
        maybe_start_listener([]) ++
        [
          # Start to serve requests, typically the last entry
          FFWeb.Endpoint
        ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FF.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp maybe_start_listener(children) do
    if Application.get_env(:app, :env) == :test do
      children
    else
      children ++ [FF.Notifications.Listener]
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FFWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
