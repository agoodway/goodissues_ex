# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :good_issues, :scopes,
  user: [
    default: true,
    module: GI.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :binary_id,
    schema_table: :users,
    test_data_fixture: GI.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :good_issues,
  env: config_env(),
  namespace: GI,
  ecto_repos: [GI.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configure the endpoint
config :good_issues, GIWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: GIWeb.ErrorHTML, json: GIWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: GI.PubSub,
  live_view: [signing_salt: "IZyyOJPs"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :good_issues, GI.Mailer, adapter: Swoosh.Adapters.Local
config :good_issues, :mailer_from, {"GoodIssues", "contact@example.com"}

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  app: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  app: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Anubis MCP session store
config :anubis_mcp, :session_store,
  enabled: true,
  adapter: GIWeb.MCP.SessionStore

# Configure Oban
config :good_issues, Oban,
  repo: GI.Repo,
  queues: [
    default: 10,
    notifications_email: 10,
    notifications_webhook: 5,
    notifications_telegram: 5,
    checks: 10,
    heartbeats: 10,
    maintenance: 2
  ]

# Oban cron plugin for periodic workers (reaper, etc.)
# Excluded in test — see test.exs.
if config_env() != :test do
  config :good_issues, Oban,
    plugins: [
      {Oban.Plugins.Cron,
       crontab: [
         {"* * * * *", GI.Monitoring.Workers.Reaper},
         {"* * * * *", GI.Monitoring.Workers.HeartbeatRecovery}
       ]}
    ]
end

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
