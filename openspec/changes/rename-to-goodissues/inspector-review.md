# Inspector Review — rename-to-goodissues

**Date**: 2026-05-09
**Verdict**: Ready (after patches applied)

## Summary

Reviewed proposal, design, tasks, and delta spec for structural correctness, cross-change consistency, and codebase alignment. Two agents inspected the change in parallel.

- **Original findings**: 3 Critical, 8 Warning, 6 Suggestion
- **Auto-patched**: 8
- **User-guided patches**: 4
- **Skipped**: 0
- **Remaining unresolved**: 5 (all Suggestions — nice-to-have)

## Patches applied

8 findings were auto-patched. 4 findings were patched after user guidance. 0 findings were skipped.

### Auto-patched

1. **Missing pre-rename clean step** — `tasks.md` → Added section 0 with task 0.1 (`rm -rf _build deps`)
2. **Task 3.11 conditional wording** — `tasks.md:3.11` → Marked N/A with explanation (esbuild/tailwind use their own atoms, not `:good_issues`)
3. **Missing go mod tidy task** — `tasks.md` → Added task 7.1a after module rename
4. **Task 9.4 treats canonical specs as best-effort** — `tasks.md:9.4` → Split into 9.4a (canonical delta specs: bot-user `.goodissues.internal`, harden-check-scheduling `GI.Monitoring.Workers.Reaper`) and 9.4b (narrative, best-effort)
5. **Task 9.3 missing directory path updates** — `tasks.md:9.3` → Expanded scope to include monorepo structure diagram paths in `openspec/project.md`
6. **Task 10.7 unscoped grep** — `tasks.md:10.7` → Added path exclusions (`_build/`, `deps/`, `.git/`, `archive/`)
7. **Proposal Modified Capabilities misleading** — `proposal.md` → Added note about delta spec text updates in active changes
8. **openapi.json should be regenerated, not manually edited** — `tasks.md:6.1-6.2` → Changed to regenerate via `mix openapi` then verify
9. **Missing compiled binary cleanup** — `tasks.md` → Added task 7.9 to remove `cli/goodissues` binary and add to `.gitignore`

### User-guided patches

1. **Cross-change ordering conflict with add-otel-ingestion** — `proposal.md` → Added Dependencies section: rename MUST land first, subsequent changes use new naming (user chose: rename lands first)
2. **Missing CLI config directory scenario in delta spec** — `specs/branding/spec.md` → Added scenario for `~/.goodissues/` config directory (user chose: add scenario, no migration)
3. **Docker/GitHub path references in site docs** — `tasks.md` → Added tasks 8.11-8.14 for Docker image, container names, Go install path, and env var renames (user chose: update all paths)
4. **Seed data project prefix "FF"** — `tasks.md:4.9` → Expanded to include prefix change `"FF"` → `"GI"` (user chose: change to GI)

## Remaining findings

### Suggestion

1. **Delta spec uses WHEN/THEN for static structural constraints** — `specs/branding/spec.md:9-11` — The "Elixir modules use GI prefix" scenario is a static constraint, not event-driven behavior. Consider rephrasing as a plain SHALL statement.
2. **Single requirement block covers many dimensions** — `specs/branding/spec.md` — All rename dimensions are bundled under one requirement. Consider splitting into separate requirements (module naming, OTP identity, CLI identity, email domains) for traceability.
3. **go.sum regeneration not explicit** — Covered by new task 7.1a (`go mod tidy`).
4. **FRUITFLY_URL/FRUITFLY_API_KEY env vars are doc-only** — `site/src/pages/docs/cli.astro:256-270` — These env vars appear in docs but aren't implemented in CLI source. The rename task (8.14) will update them, but consider whether to implement them in the CLI or remove from docs.
5. **Docker Hub repo rename not in scope** — The git/Docker Hub repo rename is listed as a non-goal, but tasks now reference `goodway/goodissues` image name. Ensure the Docker Hub repo is renamed before site docs go live.
