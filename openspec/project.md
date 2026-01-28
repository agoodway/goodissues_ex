# Project Context

## Purpose
FruitFly is a bug and feature request tracking system providing a REST API for managing projects and issues. It supports multi-tenant accounts with role-based API key access.

## Tech Stack
- **Backend**: Elixir/Phoenix 1.8, Ecto, PostgreSQL
- **CLI**: Go, Cobra, Viper
- **API**: REST with OpenAPI 3.0 spec, Bearer token auth

## Monorepo Structure
```
fruitfly/
├── app/                    # Phoenix/Elixir backend API
│   ├── lib/app/            # Core business logic (contexts)
│   ├── lib/app_web/        # Web layer (controllers, views, router)
│   ├── priv/repo/          # Database migrations
│   └── openapi.json        # OpenAPI specification
├── cli/                    # Go CLI client
│   ├── cmd/                # Cobra commands
│   └── internal/           # Internal packages (client, config)
└── openspec/               # Spec-driven development
```

## Project Conventions

### Code Style
- Elixir: Run `mix format` before commits
- Go: Run `go fmt` before commits
- Use conventional commits (feat:, fix:, docs:, chore:)

### Architecture Patterns
- Phoenix contexts for business logic separation
- RESTful API design with JSON responses
- Multi-tenant via account scoping
- API keys with permission levels (pk_* read-only, sk_* read/write)

### Testing Strategy
- Elixir: ExUnit with DataCase for database tests
- API tests in `test/app_web/controllers/`
- CLI: Go testing package

### Git Workflow
- Main branch for releases
- Feature branches for development
- Conventional commit messages

## Domain Context
- **Account**: Tenant container for projects and users
- **Project**: Container for issues within an account
- **Issue**: Bug or feature request with status, priority, type
- **API Key**: Scoped to account membership, pk_* or sk_* prefix

## Important Constraints
- API keys must be scoped to a single account membership
- Issues require a project_id
- All API endpoints require Bearer token authentication

## External Dependencies
- PostgreSQL database
- No external services currently
