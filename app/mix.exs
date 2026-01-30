defmodule FF.MixProject do
  use Mix.Project

  def project do
    [
      app: :app,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:ex_unit, :mix]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {FF.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [check: :test, precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # Phoenix Core
      {:phoenix, "~> 1.8"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_live_dashboard, "~> 0.8"},

      # Assets
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},

      # HTTP Client (always use Req, never HTTPoison/Tesla)
      {:req, "~> 0.5"},

      # Email
      {:swoosh, "~> 1.16"},

      # Background Jobs
      {:oban, "~> 2.18"},

      # Security
      {:bcrypt_elixir, "~> 3.0"},

      # OpenAPI Documentation
      {:open_api_spex, "~> 3.21"},

      # CORS support
      {:cors_plug, "~> 3.0"},

      # MCP Server
      {:anubis_mcp, "~> 0.17"},

      # Environment & Config
      {:dotenvy, "~> 1.1"},

      # Utilities
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},

      # Development Tools
      {:tidewave, "~> 0.5", only: :dev},

      # Code Quality (dev/test only)
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.21", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},

      # Testing
      {:lazy_html, ">= 0.1.0", only: :test},
      {:mimic, "~> 1.10", only: :test}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind app", "esbuild app"],
      "assets.deploy": [
        "tailwind app --minify",
        "esbuild app --minify",
        "phx.digest"
      ],
      check: [
        "compile --warnings-as-errors",
        "deps.unlock --unused",
        "format --check-formatted",
        "credo --strict",
        "doctor",
        "dialyzer",
        "test"
      ],
      precommit: ["check"]
    ]
  end
end
