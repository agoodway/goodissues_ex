import Config

# Environment for compile-time checks
config :good_issues, env: :test

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :good_issues, GI.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "app_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :good_issues, GIWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "JPICfNhXUZWiqKnA25T2lZJoVJrbyvOjOLCiWKbea5xn48eLyNQw4pluCXHGB64j",
  server: false

# In test we don't send emails
config :good_issues, GI.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Use mock Telegram client in tests (set per-test via Mimic)
config :good_issues, :telegram_client, GI.Notifications.TelegramClient.HTTP

# In tests, jobs are inserted but not executed — call Oban.drain_queue/1
# (or invoke a worker's perform/1 directly) when test logic needs them
# to run. The isolated notifier avoids LISTEN/NOTIFY connection pressure.
# No plugins in test — cron plugin lives in dev.exs / prod.exs only.
config :good_issues, Oban,
  testing: :manual,
  notifier: Oban.Notifiers.Isolated

# Deterministic Cloak key for tests (32 bytes)
config :good_issues, GI.Vault,
  ciphers: [
    default:
      {Cloak.Ciphers.AES.GCM,
       tag: "AES.GCM.V1", key: Base.decode64!("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")}
  ]

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
