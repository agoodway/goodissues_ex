defmodule GI.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias GI.Monitoring.{HeartbeatScheduler, Scheduler}

  @impl true
  def start(_type, _args) do
    # MCP Server - only in dev
    children =
      [
        GIWeb.Telemetry,
        GI.Repo,
        {DNSCluster, query: Application.get_env(:good_issues, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: GI.PubSub},
        {Oban, Application.fetch_env!(:good_issues, Oban)}
      ] ++
        if(Application.get_env(:good_issues, :dev_routes), do: [GIWeb.MCP.Supervisor], else: []) ++
        maybe_start_listener([]) ++
        [
          # Start to serve requests, typically the last entry
          GIWeb.Endpoint
        ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GI.Supervisor]

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
    if Application.get_env(:good_issues, :env) != :test do
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
    if Application.get_env(:good_issues, :env) == :test do
      children
    else
      children ++ [GI.Notifications.Listener]
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GIWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
