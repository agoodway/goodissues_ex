# Change: Add Telemetry UI to Issue Detail

## Why

FruitFly collects telemetry spans (request timing, database queries, LiveView events) alongside error reports. Both can be correlated by `request_id` - errors store it in `occurrence.context.request_id` while telemetry spans store it directly in `span.request_id`.

Currently, the issue detail page shows error data (kind, reason, stacktrace) but doesn't show the associated telemetry data. Displaying telemetry on the issue detail page helps users understand the full request lifecycle that led to an error - including timing, database queries, and other events.

## What Changes

- Add a new "Request Timeline" section to the issue detail page below the Error Details card
- When viewing an issue with an error, extract `request_id` from the first occurrence's context
- Query and display telemetry spans associated with that `request_id`
- Show spans in a timeline format: timestamp, event type, event name, duration
- Each span row expandable to show context and measurements data
- Handle case where no telemetry data exists (empty state)
- Handle case where error has no `request_id` in context

## Impact

- Affected specs: `issues-ui` (add telemetry display requirements)
- Affected code:
  - `app/lib/app_web/live/dashboard/issue_live/show.ex` - Load and display telemetry spans
  - `app/assets/css/app.css` - Add styling for telemetry timeline
  - `app/lib/app/telemetry.ex` - May need new query function for project-scoped request lookup
