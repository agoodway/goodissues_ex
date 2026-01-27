# FruitFly

A Phoenix application with REST API and MCP (Model Context Protocol) server support.

## Getting Started

```bash
# Install dependencies
mix setup

# Start the server
mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000) from your browser.

## API Authentication

FruitFly uses API keys for programmatic access. There are two types:

| Type | Prefix | Permissions |
|------|--------|-------------|
| Public | `pk_` | Read-only access |
| Private | `sk_` | Full read/write access |

### Creating an API Key

1. Register a user account at `/users/register`
2. Create an API key via IEx:

```elixir
# Get the user with their account memberships
user = FF.Accounts.get_user_by_email("your@email.com")
user = FF.Repo.preload(user, :account_users)
account_user = hd(user.account_users)

# Create an API key with scopes
{:ok, api_key, token} = FF.Accounts.create_api_key(account_user, %{
  name: "My API Key",
  type: :private,
  scopes: ["accounts:read", "api_keys:read"]
})

# IMPORTANT: Save the token - it's only shown once
IO.puts("API Key: #{token}")
```

### Available Scopes

| Scope | Description |
|-------|-------------|
| `accounts:read` | List and view accounts |
| `accounts:write` | Create and update accounts |
| `api_keys:read` | List API keys |
| `api_keys:write` | Create and manage API keys |

## REST API

### Documentation

- **OpenAPI Spec**: `GET /api/v1/openapi`
- **Swagger UI**: `GET /api/v1/docs`

### Authentication

Include your API key in the `Authorization` header:

```bash
curl -H "Authorization: Bearer pk_your_api_key_here" \
  http://localhost:4000/api/v1/resources
```

### Example Requests

```bash
# List resources (read access)
curl -H "Authorization: Bearer pk_..." \
  http://localhost:4000/api/v1/resources

# Create resource (write access required)
curl -X POST \
  -H "Authorization: Bearer sk_..." \
  -H "Content-Type: application/json" \
  -d '{"name": "Example"}' \
  http://localhost:4000/api/v1/resources
```

## MCP Server

FruitFly includes an MCP server that allows AI assistants like Claude to interact with your data programmatically.

### What is MCP?

[Model Context Protocol (MCP)](https://modelcontextprotocol.io) is an open protocol that standardizes how AI applications provide context to LLMs. It enables Claude to:

- **Tools**: Execute operations (list accounts, create resources, etc.)
- **Resources**: Read data from your application
- **Prompts**: Use predefined templates

### Setup with Claude CLI

1. **Start the Phoenix server**:
   ```bash
   mix phx.server
   ```

2. **Create an API key with MCP scopes**:
   ```elixir
   {:ok, _api_key, token} = FF.Accounts.create_api_key(account_user, %{
     name: "Claude MCP",
     type: :private,
     scopes: ["accounts:read", "api_keys:read"]
   })
   ```

3. **Add the MCP server to Claude CLI**:
   ```bash
   claude mcp add --transport http fruitfly \
     "http://localhost:4000/mcp" \
     --header "Authorization: Bearer sk_your_token_here"
   ```

4. **Verify the connection**:
   ```bash
   claude mcp list
   ```

### Alternative: Project Configuration

Add to `.mcp.json` in your project root:

```json
{
  "mcpServers": {
    "fruitfly": {
      "type": "http",
      "url": "http://localhost:4000/mcp",
      "headers": {
        "Authorization": "Bearer sk_your_token_here"
      }
    }
  }
}
```

### Available MCP Tools

| Tool | Required Scope | Description |
|------|----------------|-------------|
| `hello_world` | None | Test tool that returns a greeting |
| `accounts_list` | `accounts:read` | List accounts with pagination |
| `accounts_get` | `accounts:read` | Get a single account by ID |
| `accounts_users_list` | `accounts:read` | List users in an account |
| `api_keys_list` | `api_keys:read` | List your API keys |

### Using MCP with Claude

Once configured, you can ask Claude to interact with your FruitFly instance:

```
> Can you list the accounts in FruitFly?

> Get details for account abc123

> Show me my API keys
```

### Adding Custom Tools

Create a new tool module in `lib/app_web/mcp/tools/`:

```elixir
defmodule FFWeb.MCP.Tools.MyDomain do
  alias FFWeb.MCP.Tools.Base
  alias Hermes.Server.Component.Tool

  def tools do
    [
      %Tool{
        name: "my_tool",
        description: "Does something useful",
        input_schema: %{
          "type" => "object",
          "required" => ["param"],
          "properties" => %{
            "param" => %{"type" => "string", "description" => "A parameter"}
          }
        }
      }
    ]
  end

  def handle("my_tool", %{"param" => param}, state) do
    Base.with_scope(state, "mydomain:read", fn _api_key ->
      # Your logic here
      {:reply, Base.success_response(%{result: param}), state}
    end)
  end
end
```

Then register it in `lib/app_web/mcp/server.ex`:

```elixir
@tool_modules [
  Tools.Accounts,
  Tools.MyDomain  # Add your module
]
```

## Development

### Code Quality

```bash
# Run all checks
mix check

# Individual checks
mix format --check-formatted
mix credo --strict
mix dialyzer
mix test
```

### Database

```bash
# Create and migrate
mix ecto.setup

# Reset database
mix ecto.reset

# Run migrations
mix ecto.migrate
```

## Production

See the [Phoenix deployment guides](https://hexdocs.pm/phoenix/deployment.html).

For MCP in production:
- Use HTTPS for the MCP endpoint
- Implement rate limiting
- Monitor tool execution times
- Rotate API keys regularly
