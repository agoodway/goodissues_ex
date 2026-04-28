## Why

FruitFly's uptime checks monitor endpoints actively — FruitFly pings URLs on a schedule. But many production failures happen in background jobs, cron tasks, and data pipelines that can't be reached from outside. These jobs fail silently: no error, no log, just absence. Heartbeat monitoring inverts the pattern — jobs ping FruitFly to prove they're alive. If a ping doesn't arrive on time, FruitFly creates an incident. This completes the monitoring story alongside active checks.

## What Changes

- New `Heartbeat` resource scoped to projects — configurable dead man's switch monitors with unique 42-character ping tokens, interval-based scheduling, and grace periods
- New `HeartbeatPing` append-only log recording each ping received (kind, exit code, JSON payload, computed duration)
- Public ping endpoints accepting success, start, and fail signals via the ping token embedded in the URL
- Per-heartbeat self-rescheduling Oban deadline workers that detect missed pings and trigger the existing incident lifecycle
- Context-aware alert rules (jsonb) evaluated against ping payloads — alerts fire even when pings arrive if payload fields violate configured thresholds
- Duration tracking computed from `/start` → `/ping` pairs, alertable via the same rule system
- Management API endpoints for heartbeat CRUD and ping history retrieval

## Capabilities

### New Capabilities

- `heartbeat-monitoring`: Heartbeat configuration, ping token generation, ping reception, deadline scheduling, and ping storage
- `heartbeat-alerting`: Context-aware alert rule evaluation on ping payloads and duration-based alerting via the existing incident lifecycle

### Modified Capabilities

None in this change directory — heartbeat monitoring depends on the incident lifecycle, bot user, issue type, and check-runner infrastructure introduced by `add-uptime-checks`.

## Impact

- **Database**: New `heartbeats` and `heartbeat_pings` tables
- **Schemas**: New `Heartbeat` and `HeartbeatPing` Ecto schemas in `FF.Monitoring`
- **Contexts**: Extend `FF.Monitoring` with heartbeat CRUD, ping recording, deadline checking, and alert rule evaluation
- **API**: New heartbeat management endpoints under `/api/v1/projects/:project_id/heartbeats`; new ping endpoints under `/api/v1/projects/:project_id/heartbeats/:token/ping[/start|/fail]`
- **Auth**: Add `heartbeats:read` and `heartbeats:write` API key scopes; ping endpoints authenticate via token in URL (no Bearer)
- **Workers**: New `FF.Monitoring.Workers.HeartbeatDeadline` Oban worker in `:heartbeats` queue with self-rescheduling pattern
- **Dependencies**: No new dependencies — Oban and Req already present
- **OpenAPI**: Add OpenApiSpex controller/schema metadata for heartbeat endpoints, exempt public ping operations from Bearer auth in generated docs, then regenerate `app/openapi.json`
- **Prerequisite**: `add-uptime-checks` (or an equivalent reconciled change) must land first so the monitoring context, incident lifecycle, and bot-user support exist
