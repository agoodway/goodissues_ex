## Context

The project currently uses these naming conventions:
- **Elixir modules**: `GI.*` / `GIWeb.*` (prefix), OTP app `:good_issues`
- **Directory structure**: `lib/app/`, `lib/app_web/`, `test/app/`
- **Go CLI**: module `goodissues`, binary `goodissues`, config dir `~/.goodissues/`
- **Brand/domains**: "GoodIssues", `goodissues.dev`, `.goodissues.internal`
- **Site**: Astro docs site with ~131 references across 11 files

Total: ~260 occurrences across 63 files. No production users or external integrations depend on the current names.

## Goals / Non-Goals

**Goals:**
- Complete rename from GoodIssues → GoodIssues across all layers in one change
- Maintain all existing functionality — zero behavioral changes
- Clean naming: `GI.*` modules, `:good_issues` OTP app, `goodissues` CLI

**Non-Goals:**
- Changing API endpoints, request/response shapes, or auth mechanisms
- Renaming the git repository or GitHub remote (separate ops concern)
- Setting up actual `goodissues.dev` DNS/email infrastructure
- Changing the project prefix in issues (e.g., `FF-123` data in the DB stays as-is)

## Decisions

### 1. Module prefix: `GI` (not `GoodIssues`)

`GI` keeps the same brevity as `FF`. `GoodIssues` would be verbose for a prefix that appears on every module. Web modules become `GIWeb.*`.

### 2. OTP app name: `:good_issues`

Follows Elixir convention (snake_case). This changes:
- All `config :app` → `config :good_issues`
- `lib/app/` → `lib/good_issues/`, `lib/app_web/` → `lib/good_issues_web/`
- `lib/app.ex` → `lib/good_issues.ex`, `lib/app_web.ex` → `lib/good_issues_web.ex`
- Database names: `app_dev` → `good_issues_dev`, `app_test` → `good_issues_test`

### 3. Migration module names: rename all

Ecto tracks migrations by timestamp, not module name. Renaming `GI.Repo.Migrations.*` → `GI.Repo.Migrations.*` is safe. The `schema_migrations` table only stores the version number.

### 4. Go module: `goodissues` (not `good_issues` or `good-issues`)

Go convention is lowercase, no separators. The `go.mod` module line becomes `module goodissues`. CLI binary name matches.

### 5. Execution order: Elixir first, then CLI, then docs/site

The Elixir rename is the riskiest (compilation must succeed). Do it first so issues surface early. CLI is independent. Docs/site are cosmetic.

### 6. File rename strategy: `git mv` for directory renames

Use `git mv` for `lib/app/` → `lib/good_issues/` etc. so git tracks the rename. For content changes within files, use find-and-replace.

## Risks / Trade-offs

- **[Risk] Missed reference causes compile error** → Full `mix compile` after Elixir rename catches all module references. Grep for residual `FF\.` and `:good_issues` afterward.
- **[Risk] Config key mismatch** → `config :app` appears 28 times across 5 config files. Systematic replacement with `config :good_issues`. Verify with `mix phx.server` startup.
- **[Risk] Database needs recreation** → DB names derived from OTP app name. Run `mix ecto.reset` after rename. No production data to migrate.
- **[Risk] Go import paths break** → Module rename in `go.mod` requires updating all internal import paths (`goodissues/cmd` → `goodissues/cmd`, `goodissues/internal/...` → `goodissues/internal/...`). Verify with `go build`.
- **[Risk] Stale _build artifacts** → `rm -rf _build deps` before recompiling under new app name.

## Migration Plan

1. Clean build artifacts: `rm -rf _build deps`
2. Apply all Elixir renames (modules, configs, dirs)
3. `mix deps.get && mix compile` — verify clean compilation
4. `mix ecto.reset` — recreate databases under new names
5. `mix test` — verify all tests pass
6. Apply Go CLI renames, `go build` — verify
7. Apply site/docs/openspec renames
8. Verify site builds if applicable

Rollback: `git checkout .` — everything is local, no infrastructure changes.
