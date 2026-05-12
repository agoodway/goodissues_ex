import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# Load .env file for development and test environments
# In production, environment variables should be set by the deployment platform
if config_env() in [:dev, :test] do
  env_files = [
    ".env.#{config_env()}.local",
    ".env.#{config_env()}",
    ".env.local",
    ".env"
  ]

  existing_files = Enum.filter(env_files, &File.exists?/1)

  env_vars =
    existing_files
    |> Enum.reverse()
    |> Enum.reduce(%{}, fn file, acc ->
      case Dotenvy.source(file) do
        {:ok, vars} -> Map.merge(acc, vars)
        _ -> acc
      end
    end)

  Enum.each(env_vars, fn {key, value} ->
    if is_nil(System.get_env(key)) do
      System.put_env(key, value)
    end
  end)
end

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/app start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
# Cloak encryption key for sensitive fields (e.g., Telegram bot tokens)
# Generate with: 32 |> :crypto.strong_rand_bytes() |> Base.encode64()
cloak_key =
  case System.get_env("CLOAK_KEY") do
    nil ->
      if config_env() == :prod do
        raise """
        environment variable CLOAK_KEY is missing.
        Generate one with: 32 |> :crypto.strong_rand_bytes() |> Base.encode64()
        """
      end

      nil

    key ->
      decoded = Base.decode64!(key)

      if byte_size(decoded) != 32 do
        raise "CLOAK_KEY must decode to exactly 32 bytes (got #{byte_size(decoded)})"
      end

      decoded
  end

if cloak_key do
  config :good_issues, GI.Vault,
    ciphers: [
      default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: cloak_key}
    ]
end

if System.get_env("PHX_SERVER") do
  config :good_issues, GIWeb.Endpoint, server: true
end

config :good_issues, GIWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []
  db_ssl? = System.get_env("ECTO_SSL", "true") in ~w(true 1)

  config :good_issues, GI.Repo,
    ssl: db_ssl?,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :good_issues, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :good_issues, GIWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :good_issues, GIWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :good_issues, GIWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # Postmark mailer adapter
  config :good_issues, GI.Mailer,
    adapter: Swoosh.Adapters.Postmark,
    api_key:
      System.get_env("POSTMARK_API_KEY") ||
        raise("environment variable POSTMARK_API_KEY is missing.")

  # Mailer from address
  config :good_issues,
         :mailer_from,
         {System.get_env("MAILER_FROM_NAME", "GoodIssues"),
          System.get_env("MAILER_FROM_EMAIL") ||
            raise("environment variable MAILER_FROM_EMAIL is missing.")}

  # CORS configuration
  config :cors_plug,
    origin: System.get_env("CORS_ORIGINS", "https://yourapp.com") |> String.split(","),
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    headers: ["Content-Type", "Authorization", "Accept"]
end
