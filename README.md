# GoodissuesEx

Elixir API client for GoodIssues, generated at compile time from the OpenAPI
schema in `../app/openapi.json` using
[`can_opener`](https://github.com/agoodway/can_opener).

## Usage

```elixir
client = GoodissuesEx.client(base_url: "http://localhost:4000", api_key: "sk_...")

{:ok, projects} = GoodissuesEx.projects(client)
{:ok, project} = GoodissuesEx.projects(client, %{name: "Demo"})
```

You can also configure defaults with application env:

```elixir
config :goodissues_ex,
  base_url: "https://api.example.com",
  api_key: "sk_..."
```

Generated schema structs live under `GoodissuesEx.Schemas`:

```elixir
GoodissuesEx.Schemas.ProjectResponse.from_map(%{"name" => "Demo"})
```

`can_opener` currently derives function names directly from paths. Parameterized
paths are exposed with literal parameter names in the function atom, for example
`apply(GoodissuesEx, :"projects_{id}", [client])`.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `goodissues_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:goodissues_ex, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/goodissues_ex>.
