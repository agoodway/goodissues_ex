# GoodissuesEx

Elixir client for the [GoodIssues](https://github.com/agoodway/goodissues) API. The entire client is generated at compile time from the OpenAPI specification using [CanOpener](https://github.com/agoodway/can_opener) -- no hand-written endpoint code, fully typed structs, and zero runtime reflection.

## Installation

Add `goodissues_ex` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:goodissues_ex, git: "https://github.com/agoodway/goodissues.git", sparse: "goodissues_ex"}
  ]
end
```

## Configuration

Configure defaults in your application config:

```elixir
# config/config.exs
config :goodissues_ex,
  base_url: "https://goodissues.dev",
  api_key: "sk_..."
```

Or pass options when creating a client:

```elixir
client = GoodissuesEx.client(
  base_url: "https://goodissues.dev",
  api_key: "sk_..."
)
```

## Authentication

GoodIssues uses Bearer token authentication with two key types:

- **`pk_*`** -- read-only public keys
- **`sk_*`** -- full read/write secret keys

API keys are scoped to a specific account. To access multiple accounts, create separate keys for each.

Heartbeat ping endpoints authenticate via the heartbeat token in the URL and do not require a Bearer token.

## Usage

### Projects

```elixir
client = GoodissuesEx.client(api_key: "sk_...")

# List projects
{:ok, %{data: projects, meta: meta}} = GoodissuesEx.list_projects(client)

# Create a project
{:ok, project} = GoodissuesEx.create_project(client, %{name: "My App", description: "Production application"})

# Get a project by ID
{:ok, project} = GoodissuesEx.show_project(client, project_id)

# Update a project
{:ok, project} = GoodissuesEx.update_project(client, project_id, %{name: "Renamed App"})

# Delete a project
{:ok, _} = GoodissuesEx.delete_project(client, project_id)
```

### Issues

```elixir
# List issues
{:ok, %{data: issues}} = GoodissuesEx.list_issues(client)

# Create an issue
{:ok, %{data: issue}} = GoodissuesEx.create_issue(client, %{
  title: "Login button not working",
  type: "bug",
  priority: "high",
  project_id: project_id,
  description: "Clicking login does nothing"
})

# Get, update, delete
{:ok, %{data: issue}} = GoodissuesEx.show_issue(client, issue_id)
{:ok, %{data: issue}} = GoodissuesEx.update_issue(client, issue_id, %{status: "in_progress"})
{:ok, _} = GoodissuesEx.delete_issue(client, issue_id)
```

**Issue types:** `bug`, `incident`, `feature_request`
**Priorities:** `low`, `medium`, `high`, `critical`
**Statuses:** `new`, `in_progress`, `archived`

### Incidents

```elixir
# List incidents
{:ok, %{data: incidents}} = GoodissuesEx.list_incidents(client)

# Report an incident
{:ok, %{data: incident}} = GoodissuesEx.create_incident(client, %{
  project_id: project_id,
  title: "Database connection pool exhausted",
  severity: "critical"
})

# Get an incident
{:ok, %{data: incident}} = GoodissuesEx.show_incident(client, incident_id)

# Update an incident
{:ok, %{data: incident}} = GoodissuesEx.update_incident(client, incident_id, %{severity: "major"})

# Resolve an incident
{:ok, %{data: incident}} = GoodissuesEx.resolve_incident(client, incident_id, %{})
```

### Error Tracking

```elixir
# Report an error (deduplicates by fingerprint)
{:ok, %{data: error}} = GoodissuesEx.create_error(client, %{
  project_id: project_id,
  kind: "Elixir.RuntimeError",
  reason: "connection timeout",
  fingerprint: "a1b2c3d4...",  # 64-char hex string
  stacktrace: [
    %{module: "MyApp.Repo", function: "query", file: "lib/my_app/repo.ex", line: 42, arity: 2}
  ],
  context: %{user_id: 123, request_path: "/api/users"},
  breadcrumbs: ["Started request", "Authenticated user", "Querying database"]
})

# List errors
{:ok, %{data: errors}} = GoodissuesEx.list_errors(client)

# Search errors by stacktrace fields
{:ok, %{data: errors}} = GoodissuesEx.search_error(client)

# Get error with occurrences
{:ok, %{data: error}} = GoodissuesEx.show_error(client, error_id)

# Resolve or mute an error
{:ok, %{data: error}} = GoodissuesEx.update_error(client, error_id, %{status: "resolved", muted: true})
```

### Uptime Checks

```elixir
# Create a check
{:ok, %{data: check}} = GoodissuesEx.create_check(client, project_id, %{
  name: "API Health",
  url: "https://api.example.com/health",
  method: "get",
  expected_status: 200,
  interval_seconds: 300
})

# List checks for a project
{:ok, %{data: checks}} = GoodissuesEx.list_checks(client, project_id)

# Get, update, delete a check
{:ok, %{data: check}} = GoodissuesEx.show_check(client, project_id, check_id)
{:ok, %{data: check}} = GoodissuesEx.update_check(client, project_id, check_id, %{paused: true})
{:ok, _} = GoodissuesEx.delete_check(client, project_id, check_id)

# List check results
{:ok, %{data: results}} = GoodissuesEx.list_check_results(client, project_id, check_id)
```

### Heartbeat Monitors

Heartbeats monitor cron jobs and scheduled tasks. If a heartbeat doesn't receive a ping within its expected interval, it creates an issue.

```elixir
# Create a heartbeat
{:ok, %{data: heartbeat}} = GoodissuesEx.create_heartbeat(client, project_id, %{
  name: "nightly-backup",
  interval_seconds: 86400,
  grace_seconds: 1800
})
# Response includes ping_url and ping_token for use in your jobs

# List, get, update, delete
{:ok, %{data: heartbeats}} = GoodissuesEx.list_heartbeats(client, project_id)
{:ok, %{data: heartbeat}} = GoodissuesEx.show_heartbeat(client, project_id, heartbeat_id)
{:ok, %{data: heartbeat}} = GoodissuesEx.update_heartbeat(client, project_id, heartbeat_id, %{paused: true})
{:ok, _} = GoodissuesEx.delete_heartbeat(client, project_id, heartbeat_id)

# List ping history
{:ok, %{data: pings}} = GoodissuesEx.list_heartbeat_ping_histories(client, project_id, heartbeat_id)
```

#### Sending Pings

Ping endpoints authenticate via the heartbeat token in the URL and do not require a Bearer token.

```elixir
ping_client = GoodissuesEx.client(base_url: "https://goodissues.dev")

# Signal job started
GoodissuesEx.start_heartbeat_ping(ping_client, project_id, heartbeat_token, %{})

# Signal job completed
GoodissuesEx.ping_heartbeat_ping(ping_client, project_id, heartbeat_token, %{})

# Signal job failed (with optional payload)
GoodissuesEx.fail_heartbeat_ping(ping_client, project_id, heartbeat_token, %{exit_code: 1})
```

### Batch Events

Submit telemetry events in bulk:

```elixir
GoodissuesEx.create_batch_event(client, %{
  events: [
    %{
      project_id: project_id,
      event_type: "phoenix_request",
      event_name: "GET /api/users",
      duration_ms: 42.5,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      context: %{status: 200}
    }
  ]
})
```

**Event types:** `phoenix_request`, `phoenix_router`, `phoenix_error`, `liveview_mount`, `liveview_event`, `ecto_query`

## Pagination

List endpoints accept `page` and `per_page` as query parameters. Responses include a `meta` field with pagination metadata:

```elixir
{:ok, response} = GoodissuesEx.list_projects(client)

response.meta
# %GoodissuesEx.Schemas.PaginationMeta{
#   page: 1,
#   per_page: 20,
#   total: 42,
#   total_pages: 3
# }
```

## Error Handling

All operations return `{:ok, result}` or `{:error, reason}` tuples:

```elixir
case GoodissuesEx.show_project(client, project_id) do
  {:ok, project} -> handle_project(project)
  {:error, %{status: 404}} -> handle_not_found()
  {:error, %{status: 422, body: %{"errors" => errors}}} -> handle_validation(errors)
  {:error, reason} -> handle_error(reason)
end
```

## Schema Structs

CanOpener generates typed Elixir structs for all API schemas under `GoodissuesEx.Schemas.*`. You can construct them from maps:

```elixir
GoodissuesEx.Schemas.ProjectResponse.from_map(%{"name" => "Demo", "id" => "550e..."})
# %GoodissuesEx.Schemas.ProjectResponse{name: "Demo", id: "550e..."}
```

## Function Reference

All functions take a `%CanOpener.Client{}` as the first argument. Path parameters are positional arguments. Request bodies are passed as a map in the final argument.

| Function | Args | Description |
|----------|------|-------------|
| `list_projects/1` | `(client)` | List all projects |
| `create_project/2` | `(client, params)` | Create a project |
| `show_project/2` | `(client, id)` | Get a project |
| `update_project/3` | `(client, id, params)` | Update a project |
| `delete_project/2` | `(client, id)` | Delete a project |
| `list_issues/1` | `(client)` | List all issues |
| `create_issue/2` | `(client, params)` | Create an issue |
| `show_issue/2` | `(client, id)` | Get an issue |
| `update_issue/3` | `(client, id, params)` | Update an issue |
| `delete_issue/2` | `(client, id)` | Delete an issue |
| `list_incidents/1` | `(client)` | List all incidents |
| `create_incident/2` | `(client, params)` | Report an incident |
| `show_incident/2` | `(client, id)` | Get an incident |
| `update_incident/3` | `(client, id, params)` | Update an incident |
| `resolve_incident/2` | `(client, id, params)` | Resolve an incident |
| `list_errors/1` | `(client)` | List all errors |
| `create_error/2` | `(client, params)` | Report an error |
| `show_error/2` | `(client, id)` | Get an error with occurrences |
| `update_error/3` | `(client, id, params)` | Update an error |
| `search_error/1` | `(client)` | Search errors by stacktrace |
| `list_checks/2` | `(client, project_id)` | List checks for a project |
| `create_check/3` | `(client, project_id, params)` | Create a check |
| `show_check/3` | `(client, project_id, check_id)` | Get a check |
| `update_check/4` | `(client, project_id, check_id, params)` | Update a check |
| `delete_check/3` | `(client, project_id, check_id)` | Delete a check |
| `list_check_results/3` | `(client, project_id, check_id)` | List results for a check |
| `list_heartbeats/2` | `(client, project_id)` | List heartbeats for a project |
| `create_heartbeat/3` | `(client, project_id, params)` | Create a heartbeat |
| `show_heartbeat/3` | `(client, project_id, heartbeat_id)` | Get a heartbeat |
| `update_heartbeat/4` | `(client, project_id, heartbeat_id, params)` | Update a heartbeat |
| `delete_heartbeat/3` | `(client, project_id, heartbeat_id)` | Delete a heartbeat |
| `list_heartbeat_ping_histories/3` | `(client, project_id, heartbeat_id)` | List pings for a heartbeat |
| `ping_heartbeat_ping/4` | `(client, project_id, heartbeat_token, params)` | Send a success ping |
| `start_heartbeat_ping/4` | `(client, project_id, heartbeat_token, params)` | Send a start ping |
| `fail_heartbeat_ping/4` | `(client, project_id, heartbeat_token, params)` | Send a failure ping |
| `create_batch_event/2` | `(client, params)` | Submit batch telemetry events |

## How It Works

The library source is minimal -- a single `use CanOpener` macro call:

```elixir
defmodule GoodissuesEx do
  use CanOpener,
    spec: "openapi.json",
    otp_app: :goodissues_ex,
    base_url: "https://goodissues.dev",
    auth: :bearer,
    path_prefix: "/api/v1/"
end
```

At compile time, CanOpener reads `openapi.json` and generates all client functions, schema structs, and type specifications. Function names are derived from `operationId` values in the spec (with Phoenix controller-style IDs automatically converted to idiomatic Elixir names). Path parameters become positional function arguments with compile-time interpolation. The HTTP stack uses [Req](https://github.com/wojtekmach/req) with [Finch](https://github.com/sneako/finch) for connection pooling.

## License

See [LICENSE](../LICENSE) for details.
