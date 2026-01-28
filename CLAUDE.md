<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# FruitFly

FruitFly is a bug and feature request tracking system with a REST API.

## Monorepo Structure

```
fruitfly/
├── app/                    # Phoenix/Elixir backend API
│   ├── lib/app/            # Core business logic (contexts)
│   ├── lib/app_web/        # Web layer (controllers, views, router)
│   ├── priv/repo/          # Database migrations
│   ├── test/               # ExUnit tests
│   └── openapi.json        # OpenAPI specification
├── cli/                    # Go CLI client
│   ├── cmd/                # Cobra commands
│   ├── internal/           # Internal packages
│   │   ├── client/         # API client
│   │   └── config/         # Configuration management
│   └── main.go             # Entry point
└── openspec/               # Spec-driven development
    ├── project.md          # Project conventions
    ├── specs/              # Current specifications
    └── changes/            # Change proposals
```

## Components

### Backend (`app/`)
- **Framework**: Phoenix 1.8 with Elixir
- **Database**: PostgreSQL with Ecto
- **API**: REST API at `/api/v1/` with Bearer token auth
- **Key resources**: Projects, Issues, API Keys, Accounts, Users

Run the server:
```bash
cd app && mix phx.server
```

Run tests:
```bash
cd app && mix test
```

### CLI (`cli/`)
- **Language**: Go with Cobra CLI framework
- **Config**: Stored in `~/.fruitfly/config.yaml`
- **Auth**: API keys (pk_* read-only, sk_* read/write)

Build and use:
```bash
cd cli && go build -o fruitfly .
./fruitfly configure --url http://localhost:4000 --api-key sk_...
./fruitfly projects list
./fruitfly issues list
```

## Development Conventions

- Use conventional commits (feat:, fix:, docs:, chore:)
- Run `mix format` before committing Elixir code
- Run `go fmt` before committing Go code
- API changes require OpenAPI spec updates