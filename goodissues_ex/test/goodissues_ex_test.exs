defmodule GoodissuesExTest do
  use ExUnit.Case

  alias CanOpener.Client

  test "creates a GoodIssues API client" do
    assert %Client{base_url: "http://localhost:4000", auth: nil} = GoodissuesEx.client()
  end

  test "accepts explicit client options" do
    client = GoodissuesEx.client(base_url: "https://api.example.test", api_key: "sk_test")

    assert client.base_url == "https://api.example.test"
    assert client.auth == {:bearer, "sk_test"}
  end

  test "generates schemas from the OpenAPI spec" do
    assert %GoodissuesEx.Schemas.ProjectResponse{name: "Demo"} =
             GoodissuesEx.Schemas.ProjectResponse.from_map(%{"name" => "Demo"})
  end

  test "generates operations from the OpenAPI spec" do
    assert function_exported?(GoodissuesEx, :projects, 1)
    assert function_exported?(GoodissuesEx, :projects, 2)
    assert function_exported?(GoodissuesEx, :issues, 1)
    assert function_exported?(GoodissuesEx, :issues, 2)
  end
end
