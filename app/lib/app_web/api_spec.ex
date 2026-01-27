defmodule FFWeb.ApiSpec do
  @moduledoc """
  OpenAPI specification for the API.
  Provides auto-generated documentation and request/response validation.
  """
  alias FFWeb.{Endpoint, Router}
  alias OpenApiSpex.{Components, Info, OpenApi, Paths, SecurityScheme, Server}
  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [
        Server.from_endpoint(Endpoint)
      ],
      info: %Info{
        title: "FruitFly API",
        version: "1.0.0",
        description: """
        FruitFly API documentation.

        ## Authentication
        All API endpoints require authentication using API keys.

        ### API Key Types
        - **Public Keys** (`pk_...`): Read-only access
        - **Private Keys** (`sk_...`): Full read/write access

        ### How to Authenticate
        1. Log in to your account and create an API key
        2. Click the "Authorize" button in Swagger UI
        3. Enter your API key: `Bearer <your_api_key>`

        All requests must include the `Authorization` header.

        ### Multi-tenant Access
        API keys are scoped to your membership in a specific account.
        To access multiple accounts, create separate API keys for each.
        """
      },
      paths: Paths.from_router(Router),
      components: %Components{
        securitySchemes: %{
          "bearerAuth" => %SecurityScheme{
            type: "http",
            scheme: "bearer",
            bearerFormat: "API Key",
            description: """
            Enter your API key: `pk_...` (read-only) or `sk_...` (read/write)
            """
          }
        }
      },
      # Apply security globally to all endpoints
      security: [
        %{"bearerAuth" => []}
      ]
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
