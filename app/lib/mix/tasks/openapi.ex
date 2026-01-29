defmodule Mix.Tasks.Openapi.Spec do
  use Mix.Task

  @shortdoc "Generate OpenAPI specification to openapi.json"

  @moduledoc """
  Generates the OpenAPI specification from the API spec module
  and writes it to openapi.json.
  """

  def run(_) do
    # Start the application
    {:ok, _} = Application.ensure_all_started(:app)

    # Get the spec from the ApiSpec module
    spec = FFWeb.ApiSpec.spec()

    # Write to file with proper formatting
    File.write!("openapi.json", Jason.encode!(spec, pretty: true))

    Mix.shell().info("OpenAPI spec generated to openapi.json")
  end
end
