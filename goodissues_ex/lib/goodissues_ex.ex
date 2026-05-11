defmodule GoodissuesEx do
  @moduledoc """
  API client for GoodIssues.

  Create a client with `client/1`, then call the generated functions for the
  GoodIssues OpenAPI operations.

      client = GoodissuesEx.client(base_url: "https://goodissues.dev", api_key: "sk_...")

      {:ok, projects} = GoodissuesEx.projects(client)
  """

  use CanOpener,
    spec: "openapi.json",
    otp_app: :goodissues_ex,
    base_url: "https://goodissues.dev",
    auth: :bearer,
    path_prefix: "/api/v1/"
end
