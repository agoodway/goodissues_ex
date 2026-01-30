# Tasks

## Implementation Order

1. [x] Add `list_spans_by_request_id_for_project/3` to `FF.Telemetry` context
   - Query spans by request_id scoped to account and project
   - Return spans ordered by timestamp ascending
   - Verify: unit test in `telemetry_test.exs`

2. [x] Update `show.ex` LiveView to load telemetry data on mount
   - Extract `request_id` from `issue.error.occurrences[0].context["request_id"]`
   - Call `FF.Telemetry.list_spans_by_request_id_for_project/3` when request_id exists
   - Assign spans to socket (empty list if no request_id or no spans)
   - Verify: page loads without errors

3. [x] Add expandable telemetry section to issue detail template
   - Show "Request Timeline" card below Error Details when error has request_id
   - Display spans in timeline list format: event type icon, event name, duration, timestamp
   - Add empty state when no telemetry data found
   - Add collapsed/expanded state for span details (context, measurements)
   - Verify: manually test with mock data

4. [x] Add CSS styling for telemetry timeline
   - Timeline container with vertical connector line
   - Event type badges with distinct colors per type
   - Duration display formatted appropriately (ms/s)
   - Expandable detail panel styling
   - Dark/light theme support
   - Verify: visual inspection in both themes

5. [x] Add event handler for expanding/collapsing individual spans
   - Track expanded span IDs in socket assigns
   - Toggle expansion on click
   - Verify: spans expand/collapse correctly

6. [x] Write integration test for telemetry display
   - Create issue with error containing request_id in context
   - Create telemetry spans with matching request_id
   - Verify spans are displayed on issue detail page
   - Verify: test passes
