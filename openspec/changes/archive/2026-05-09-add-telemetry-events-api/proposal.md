# Change: Add Telemetry Events API

## Why

GoodIssues needs to correlate error reports with request performance data. By collecting telemetry spans from client applications (via GoodIssuesReporter), users can see the full request lifecycle including timing data, database queries, and LiveView events alongside any errors that occurred.

## What Changes

- Add `telemetry_spans` database table with indexes for efficient querying
- Add `GI.Telemetry` context with batch insert and query functions
- Add `GI.Telemetry.Span` Ecto schema with event type enum
- Add `POST /api/v1/events/batch` endpoint for bulk telemetry ingestion
- Add `events:write` scope for API authentication

## Impact

- Affected specs: New `telemetry` capability
- Affected code:
  - `app/lib/app/telemetry.ex` - New context module
  - `app/lib/app/telemetry/span.ex` - New schema
  - `app/lib/app_web/controllers/api/v1/event_controller.ex` - New controller
  - `app/lib/app_web/router.ex` - New route
  - `app/priv/repo/migrations/20260130135121_create_telemetry_spans.exs` - New migration
