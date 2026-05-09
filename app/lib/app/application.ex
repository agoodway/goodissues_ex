defmodule FF.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias FF.Monitoring.{HeartbeatScheduler, Scheduler}

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

    case Supervisor.start_link(children, opts) do
      {:ok, _pid} = ok ->
        recover_uptime_checks()
        ok

      other ->
        other
    end
  end

  defp recover_uptime_checks do
    # Re-enqueue any active checks that have no pending Oban job. Skipped
    # in test mode because tests inspect job inserts directly.
    if Application.get_env(:app, :env) != :test do
      Task.start(fn ->
        try do
          Scheduler.recover_orphaned_jobs()
          HeartbeatScheduler.recover_orphaned_jobs()
        rescue
          _ -> :ok
        end
      end)
    end

    :ok
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
