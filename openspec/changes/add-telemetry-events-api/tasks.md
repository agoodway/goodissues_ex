## 1. Database Schema

- [x] 1.1 Create migration for `telemetry_spans` table
- [x] 1.2 Add indexes for `project_id`, `request_id`, `timestamp`, `event_type`
- [x] 1.3 Add composite indexes for common query patterns

## 2. Domain Model

- [x] 2.1 Create `GI.Telemetry.Span` schema with event type enum
- [x] 2.2 Define typespec for Span struct
- [x] 2.3 Implement `create_changeset/2` with validations

## 3. Business Logic

- [x] 3.1 Create `GI.Telemetry` context module
- [x] 3.2 Implement `create_spans_batch/3` for bulk insert
- [x] 3.3 Implement `list_spans_by_request_id/2` for correlation queries
- [x] 3.4 Implement `list_spans/3` with filtering options
- [x] 3.5 Implement `get_span/2` for single span retrieval
- [x] 3.6 Add project ownership validation

## 4. API Endpoint

- [x] 4.1 Create `EventController` with `create_batch` action
- [x] 4.2 Add OpenAPI spec for batch endpoint
- [x] 4.3 Add route `POST /api/v1/events/batch`
- [x] 4.4 Implement `events:write` scope check

## 5. Testing

- [x] 5.1 Write context tests for `GI.Telemetry`
- [x] 5.2 Write controller tests for `EventController`
- [x] 5.3 Test authorization and scope requirements
