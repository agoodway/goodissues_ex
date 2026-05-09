## Why

FruitFly's uptime checks monitor endpoints actively — FruitFly pings URLs on a schedule. But many production failures happen in background jobs, cron tasks, and data pipelines that can't be reached from outside. These jobs fail silently: no error, no log, just absence. Heartbeat monitoring inverts the pattern — jobs ping FruitFly to prove they're alive. If a ping doesn't arrive on time, FruitFly creates an incident. This completes the monitoring story alongside active checks.

## What Changes

- New `Heartbeat` resource scoped to projects — configurable dead man's switch monitors with unique 42-character ping tokens, interval-based scheduling, grace periods, and a persisted `next_due_at` scheduling anchor
- New `HeartbeatPing` append-only log recording each ping received (kind, exit code, JSON payload, computed duration)
- Public ping endpoints accepting success, start, and fail signals via the ping token embedded in the URL
- Per-heartbeat deadline workers that adopt the same hardened scheduling model as `harden-check-scheduling`: unconditional reschedule/recovery semantics, stale-job invalidation, and periodic orphan/stuck-job recovery
- Context-aware alert rules (jsonb) evaluated against ping payloads — alerts fire even when pings arrive if payload fields violate configured thresholds
- Duration tracking computed from `/start` → `/ping` pairs, alertable via the same rule system
- Management API endpoints for heartbeat CRUD and ping history retrieval
- Treat ping tokens as write-capable secrets: return the full ping URL on create flows, but redact token-bearing fields from later read-only management responses
- Serialize ping and deadline state transitions so races do not double-count failures or create/archive the wrong incident

## Capabilities

### New Capabilities

- `heartbeat-monitoring`: Heartbeat configuration, ping token generation, ping reception, deadline scheduling, and ping storage
- `heartbeat-alerting`: Context-aware alert rule evaluation on ping payloads and duration-based alerting via heartbeat-specific incident handling that preserves the existing lifecycle rules

### Modified Capabilities

- `incident-lifecycle`: Extend monitoring-driven incident creation, reopening, archival, and issue-link maintenance to heartbeat failures and recoveries

## Impact

- **Database**: New `heartbeats` and `heartbeat_pings` tables
- **Schemas**: New `Heartbeat` and `HeartbeatPing` Ecto schemas in `FF.Monitoring`
- **Contexts**: Extend `FF.Monitoring` with heartbeat CRUD, ping recording, deadline checking, alert rule evaluation, locked state transitions for ping/deadline races, and a heartbeat-specific incident lifecycle wrapper
- **API**: New heartbeat management endpoints under `/api/v1/projects/:project_id/heartbeats`; new ping endpoints under `/api/v1/projects/:project_id/heartbeats/:heartbeat_token/ping[/start|/fail]`
- **Auth**: Add `heartbeats:read` and `heartbeats:write` API key scopes; ping endpoints authenticate via token in URL (no Bearer); read-only heartbeat responses redact token-bearing fields
- **Workers**: New `FF.Monitoring.Workers.HeartbeatDeadline` Oban worker in `:heartbeats` queue with the hardened scheduling invariants from `harden-check-scheduling`, plus a heartbeat-specific periodic recovery worker for orphaned/stuck deadline jobs
- **Dependencies**: No new dependencies — Oban and Req already present
- **OpenAPI**: Add OpenApiSpex controller/schema metadata for heartbeat endpoints, exempt public ping operations from Bearer auth in generated docs, then regenerate `app/openapi.json`
- **Prerequisites**: `add-uptime-checks` and `harden-check-scheduling` (or equivalent reconciled changes) must land first so the monitoring context, incident lifecycle, and hardened monitoring-job invariants exist
