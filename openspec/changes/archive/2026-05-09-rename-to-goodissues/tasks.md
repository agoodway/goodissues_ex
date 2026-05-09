## 0. Pre-Rename Preparation

- [x] 0.1 Clean build artifacts: `rm -rf _build deps` in `app/`

## 1. Elixir — Directory and File Renames

- [x] 1.1 Rename `app/lib/app.ex` → `app/lib/good_issues.ex`
- [x] 1.2 Rename `app/lib/app_web.ex` → `app/lib/good_issues_web.ex`
- [x] 1.3 Rename `app/lib/app/` → `app/lib/good_issues/`
- [x] 1.4 Rename `app/lib/app_web/` → `app/lib/good_issues_web/`
- [x] 1.5 Rename `app/test/app/` → `app/test/good_issues/`
- [x] 1.6 Rename `app/test/app_web/` → `app/test/good_issues_web/`

## 2. Elixir — Module Prefix Renames

- [x] 2.1 Replace `defmodule GI.MixProject` → `defmodule GI.MixProject` in `app/mix.exs`
- [x] 2.2 Replace `GI.Application` → `GI.Application` in `app/mix.exs`
- [x] 2.3 Replace all `GI.` → `GI.` in all `.ex` and `.exs` source files under `app/lib/`
- [x] 2.4 Replace all `GIWeb.` → `GIWeb.` in all `.ex` and `.exs` source files under `app/lib/`
- [x] 2.5 Replace all `GI.` → `GI.` in all `.exs` test files under `app/test/`
- [x] 2.6 Replace all `GIWeb.` → `GIWeb.` in all `.exs` test files under `app/test/`
- [x] 2.7 Replace all `GI.` → `GI.` in all migration files under `app/priv/repo/migrations/`
- [x] 2.8 Replace `GI.` → `GI.` in `app/priv/repo/seeds.exs`
- [x] 2.9 Replace `FF` → `GI` in test support files (`app/test/support/`)

## 3. Elixir — Config File Updates

- [x] 3.1 Replace all `config :app` → `config :good_issues` in `app/config/config.exs`
- [x] 3.2 Replace all `config :app` → `config :good_issues` in `app/config/dev.exs`
- [x] 3.3 Replace all `config :app` → `config :good_issues` in `app/config/test.exs`
- [x] 3.4 Replace all `config :app` → `config :good_issues` in `app/config/prod.exs`
- [x] 3.5 Replace all `config :app` → `config :good_issues` in `app/config/runtime.exs`
- [x] 3.6 Update `GIWeb.Endpoint` → `GIWeb.Endpoint` in all config files
- [x] 3.7 Update `GI.Repo` → `GI.Repo` in all config files
- [x] 3.8 Update `GI.Mailer` → `GI.Mailer` in all config files
- [x] 3.9 Update `namespace: FF` → `namespace: GI` in `config.exs`
- [x] 3.10 Update `app: :app` → `app: :good_issues` in `app/mix.exs`
- [x] 3.11 ~~Update esbuild/tailwind config keys if they reference `:good_issues`~~ — N/A: esbuild/tailwind use their own atoms (`:esbuild`, `:tailwind`), not `:good_issues`

## 4. Elixir — Brand String Updates

- [x] 4.1 Replace `"GoodIssues"` → `"GoodIssues"` in `app/lib/app_web/api_spec.ex` (API title)
- [x] 4.2 Replace `"GoodIssues API"` → `"GoodIssues API"` in `app/lib/app_web/api_spec.ex`
- [x] 4.3 Replace `"goodissues"` → `"goodissues"` in `app/lib/app_web/mcp/server.ex` (MCP server name)
- [x] 4.4 Replace `"GoodIssues"` → `"GoodIssues"` in `app/lib/app_web/components/layouts.ex` (sidebar brand)
- [x] 4.5 Replace `[GoodIssues]` → `[GoodIssues]` in `app/lib/app/notifications/workers/email_worker.ex` (email subject)
- [x] 4.6 Replace `"GoodIssues"` → `"GoodIssues"` in `app/lib/app/notifications/workers/email_worker.ex` (from name)
- [x] 4.7 Replace `notifications@goodissues.dev` → `notifications@goodissues.dev` in email_worker.ex
- [x] 4.8 Replace `goodissues.dev` → `goodissues.dev` in `app/priv/repo/seeds.exs` (seed email domains)
- [x] 4.9 Replace `"GoodIssues"` → `"GoodIssues"` in `app/priv/repo/seeds.exs` (account/project names) and project prefix `"FF"` → `"GI"`
- [x] 4.10 Replace `.goodissues.internal` → `.goodissues.internal` in `app/lib/app/accounts/user.ex` and `app/lib/app/accounts.ex`
- [x] 4.11 Replace `.goodissues.internal` → `.goodissues.internal` in `app/test/app/accounts_test.exs`
- [x] 4.12 Replace `GoodIssuesReporter` → `GoodIssuesReporter` in `app/lib/app_web/controllers/api/v1/event_controller.ex`
- [x] 4.13 Replace `GoodIssues` → `GoodIssues` in `app/lib/app/monitoring/heartbeat.ex` (doc comments)
- [x] 4.14 Replace `GoodIssuesReporter` → `GoodIssuesReporter` in `app/lib/app/telemetry.ex` (doc comments)
- [x] 4.15 Update `goodissues` CLI references in dashboard LiveViews (`$ goodissues` → `$ goodissues`)
- [x] 4.16 Replace `goodissues` → `goodissues` in webhook placeholder URL in subscription_live/new.ex

## 5. Elixir — Template/HEEX Updates

- [x] 5.1 Replace all `GoodIssues`/`GoodIssues`/`goodissues` references in `app/lib/app_web/components/layouts/root.html.heex`
- [x] 5.2 Replace all `GoodIssues`/`goodissues` references in `app/lib/app_web/controllers/page_html/home.html.heex`

## 6. Elixir — OpenAPI Spec

- [x] 6.1 Regenerate `app/openapi.json` by running `mix openapi.spec` after all source renames are complete (this file is generated from `GIWeb.ApiSpec`)
- [x] 6.2 Verify regenerated `app/openapi.json` contains "GoodIssues" title and no residual "FruitFly"/"fruitfly" references

## 7. Go CLI — Module and Source Renames

- [x] 7.1 Replace `module goodissues` → `module goodissues` in `cli/go.mod`
- [x] 7.1a Run `go mod tidy` after module rename to regenerate `go.sum`
- [x] 7.2 Replace `goodissues/cmd` → `goodissues/cmd` in `cli/main.go`
- [x] 7.3 Replace `goodissues/internal/config` → `goodissues/internal/config` in all Go files
- [x] 7.4 Replace `goodissues/internal/client` → `goodissues/internal/client` in all Go files
- [x] 7.5 Replace `"goodissues"` → `"goodissues"` in `cli/cmd/root.go` (CLI name, Use field)
- [x] 7.6 Replace `.goodissues` → `.goodissues` in `cli/internal/config/config.go` (config dir name)
- [x] 7.7 Replace `"goodissues"` → `"goodissues"` in `cli/cmd/configure.go` (user-facing text)
- [x] 7.8 Replace `GoodIssues`/`GoodIssues` brand strings in Go source files (help text, errors)
- [x] 7.9 Remove compiled `cli/goodissues` binary from repo and add to `.gitignore`

## 8. Documentation Site

- [x] 8.1 Replace all `GoodIssues`/`GoodIssues`/`goodissues` → `GoodIssues`/`goodissues` in `site/src/pages/index.astro`
- [x] 8.2 Replace in `site/src/pages/docs/index.astro`
- [x] 8.3 Replace in `site/src/pages/docs/quickstart.astro`
- [x] 8.4 Replace in `site/src/pages/docs/authentication.astro`
- [x] 8.5 Replace in `site/src/pages/docs/cli.astro`
- [x] 8.6 Replace in `site/src/pages/docs/docker.astro`
- [x] 8.7 Replace in `site/src/pages/docs/api/projects.astro`
- [x] 8.8 Replace in `site/src/pages/docs/api/issues.astro`
- [x] 8.9 Replace in `site/src/layouts/Layout.astro` and `site/src/layouts/DocsLayout.astro`
- [x] 8.10 Replace in `site/justfile` (including Docker image tag `goodissues-site` → `goodissues-site`)
- [x] 8.11 Replace Docker Hub image `goodway/goodissues` → `goodway/goodissues` across all site pages
- [x] 8.12 Replace container names `--name goodissues` → `--name goodissues` and DB names in Docker docs
- [x] 8.13 Replace Go install path `github.com/goodway/goodissues/cli` → `github.com/goodway/goodissues/cli` in CLI docs
- [x] 8.14 Replace `FRUITFLY_URL`/`FRUITFLY_API_KEY` env var names → `GOODISSUES_URL`/`GOODISSUES_API_KEY` in CLI docs (these are doc-only, not implemented in CLI source)

## 9. Project-Level Files

- [x] 9.1 Update `CLAUDE.md` — replace all FruitFly/fruitfly references with GoodIssues/goodissues
- [x] 9.2 Update `AGENTS.md` — replace all FruitFly/fruitfly references
- [x] 9.3 Update `openspec/project.md` — replace all FruitFly/fruitfly references AND update monorepo structure diagram paths (`lib/app/` → `lib/good_issues/`, `lib/app_web/` → `lib/good_issues_web/`, `test/app/` → `test/good_issues/`)
- [x] 9.4a Update canonical requirement text in active delta specs that contain old names: `add-uptime-checks/specs/bot-user/spec.md` (`.fruitfly.internal` → `.goodissues.internal`) and `harden-check-scheduling/specs/uptime-checks/spec.md` (`FF.Monitoring.Workers.Reaper` → `GI.Monitoring.Workers.Reaper`)
- [x] 9.4b Update fruitfly references in OpenSpec change artifacts — narrative/prose only, best-effort (design docs, inspector reports, completed task descriptions)

## 10. Verification

- [x] 10.1 Clean build: `rm -rf _build deps` then `mix deps.get && mix compile`
- [x] 10.2 Run `mix test` — all tests pass
- [x] 10.3 Grep for residual `fruitfly`, `FruitFly`, `Fruitfly`, `fruit_fly` in app/ (excluding _build, deps) — found and fixed 2 residual refs
- [x] 10.4 Grep for residual `:app` config references — only esbuild/tailwind profile names remain (correct)
- [x] 10.5 Grep for residual `FF\.` or `FFWeb\.` module references in app/ — clean
- [x] 10.6 Build Go CLI: `cd cli && go build -o goodissues .` — success
- [x] 10.7 Final grep across entire repo — found and fixed refs in README.md, app.css, config.go
