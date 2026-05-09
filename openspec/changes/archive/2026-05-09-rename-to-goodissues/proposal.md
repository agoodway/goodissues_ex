## Why

The project is rebranding from "GoodIssues" to "GoodIssues" (goodissues.dev). This rename needs to propagate through all layers: Elixir modules, OTP app name, Go CLI, documentation site, OpenSpec artifacts, and configuration files.

## What Changes

- **BREAKING**: Rename Elixir module prefix from `FF` → `GI` and `FFWeb` → `GIWeb` across all source files, tests, and migrations
- **BREAKING**: Rename OTP app from `:good_issues` to `:good_issues` (config keys, lib dirs, build artifacts)
- **BREAKING**: Rename Go CLI binary from `goodissues` to `goodissues`, Go module path, config dir `~/.goodissues/` → `~/.goodissues/`
- Rename all brand strings: "GoodIssues" / "GoodIssues" → "GoodIssues"
- Update all email domains: `goodissues.dev` → `goodissues.dev`, `goodissues.internal` → `goodissues.internal`
- Update site content (~131 occurrences across 11 files)
- Update OpenSpec project.md and change artifact references
- Update CLAUDE.md, AGENTS.md project descriptions
- Update OpenAPI spec title and references
- Update MCP server name from "goodissues" to "goodissues"

## Capabilities

### New Capabilities

_None — this is a rename, not a feature change._

### Modified Capabilities

_No spec-level behavior changes — all capabilities retain their existing requirements. Only naming and branding change. Delta spec text in active changes (bot-user, uptime-checks) will be updated to reflect new module and domain names._

## Dependencies

This change MUST land before other active changes (e.g., add-otel-ingestion). Subsequent changes must use the new `GI.*`/`GIWeb.*`/`config :good_issues` naming from the start.

## Impact

- **Elixir app**: Every `.ex` and `.exs` file with `GI.` or `GIWeb.` references. Config files (`config.exs`, `dev.exs`, `prod.exs`, `runtime.exs`, `test.exs`). Directory structure (`lib/app` → `lib/good_issues`, `lib/app_web` → `lib/good_issues_web`).
- **Database**: DB names change (`app_dev` → `good_issues_dev`, etc.). Requires `mix ecto.reset`.
- **Go CLI**: All 9 source files. Module path in `go.mod`. Binary name.
- **Site**: All 11 Astro files plus layouts. justfile.
- **Build**: `_build/` must be cleaned. Dependencies re-fetched for new app name.
- **No API contract changes**: Endpoints, request/response shapes, and auth mechanisms remain identical.
