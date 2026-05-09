defmodule Mix.Tasks.Openapi.Spec do
  @shortdoc "Generate OpenAPI specification to openapi.json"

  @moduledoc """
  Generates the OpenAPI specification from the API spec module
  and writes it to openapi.json.
  """

  # Suppress dialyzer warnings for Mix module (not available in releases)
  @dialyzer [:no_behaviours, {:nowarn_function, run: 1}]

  use Mix.Task

  @impl Mix.Task
  def run(_) do
    # Start the application
    {:ok, _} = Application.ensure_all_started(:good_issues)

    # Get the spec from the ApiSpec module
    spec = GIWeb.ApiSpec.spec()

    # Write to file with proper formatting
    File.write!("openapi.json", Jason.encode!(spec, pretty: true))

    Mix.shell().info("OpenAPI spec generated to openapi.json")
  end
end
