defmodule GoodissuesEx do
  @moduledoc """
  API client for GoodIssues.

  Create a client with `client/1`, then call the generated functions for the
  GoodIssues OpenAPI operations.

      client = GoodissuesEx.client(base_url: "http://localhost:4000", api_key: "sk_...")

      {:ok, projects} = GoodissuesEx.projects(client)
  """

  use CanOpener,
    spec: "../app/openapi.json",
    otp_app: :goodissues_ex,
    base_url: "http://localhost:4000",
    auth: :bearer,
    path_prefix: "/api/v1/"
end
