
# GoodIssues

GoodIssues is a bug and feature request tracking system with a REST API.

## Monorepo Structure

```
goodissues/
├── app/                    # Phoenix/Elixir backend API
│   ├── lib/good_issues/    # Core business logic (contexts)
│   ├── lib/good_issues_web/ # Web layer (controllers, views, router)
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

### CLI (`cli/`)
- **Language**: Go with Cobra CLI framework
- **Config**: Stored in `~/.goodissues/config.yaml`
- **Auth**: API keys (pk_* read-only, sk_* read/write)

## Quick Commands

```bash
# Backend
cd app && mix phx.server      # Run server
cd app && mix test            # Run tests

# CLI
cd cli && go build -o goodissues .
./goodissues configure --url http://localhost:4000 --api-key sk_...
./goodissues projects list
./goodissues issues list
```
