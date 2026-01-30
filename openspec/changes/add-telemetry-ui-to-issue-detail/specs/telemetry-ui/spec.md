# telemetry-ui Specification

## Purpose

Display telemetry data (request timing, database queries, LiveView events) associated with error occurrences on the issue detail page, allowing users to understand the full request lifecycle that led to an error.

## MODIFIED Requirements

### Requirement: Issue Detail Telemetry Display

The issue detail page SHALL display telemetry span data when an error's occurrence contains a `request_id` in its context.

#### Scenario: Display telemetry timeline for error with request_id

- **GIVEN** a user is viewing an issue with an associated error
- **AND** the error's first occurrence has `context.request_id` set
- **AND** telemetry spans exist with that `request_id`
- **WHEN** the page loads
- **THEN** a "Request Timeline" section is displayed below the Error Details card
- **AND** each span shows: event type badge, event name, duration (if available), timestamp
- **AND** spans are ordered by timestamp ascending (earliest first)

#### Scenario: Expand span details

- **GIVEN** a user is viewing the telemetry timeline on an issue
- **WHEN** the user clicks on a span row
- **THEN** the span expands to show additional details
- **AND** the context data is displayed as key-value pairs
- **AND** the measurements data is displayed as key-value pairs
- **WHEN** the user clicks the span again
- **THEN** the details collapse

#### Scenario: No telemetry data exists

- **GIVEN** a user is viewing an issue with an error
- **AND** the error's first occurrence has `context.request_id` set
- **AND** no telemetry spans exist with that `request_id`
- **WHEN** the page loads
- **THEN** the "Request Timeline" section shows an empty state message
- **AND** the message indicates no telemetry data was found for this request

#### Scenario: No request_id in error context

- **GIVEN** a user is viewing an issue with an error
- **AND** the error's first occurrence does not have `context.request_id`
- **WHEN** the page loads
- **THEN** no "Request Timeline" section is displayed
- **AND** the error details section displays normally

#### Scenario: Issue without error

- **GIVEN** a user is viewing an issue without an associated error (manual issue)
- **WHEN** the page loads
- **THEN** no telemetry section is displayed

### Requirement: Event Type Visual Distinction

Each telemetry event type SHALL be visually distinguished using consistent styling.

#### Scenario: Event type badges

- **GIVEN** telemetry spans are displayed in the timeline
- **THEN** each span shows an event type badge
- **AND** `phoenix_request` events have a distinct color/icon
- **AND** `phoenix_router` events have a distinct color/icon
- **AND** `phoenix_error` events have a distinct color/icon (error-themed)
- **AND** `liveview_mount` events have a distinct color/icon
- **AND** `liveview_event` events have a distinct color/icon
- **AND** `ecto_query` events have a distinct color/icon

### Requirement: Duration Display

Span durations SHALL be displayed in human-readable format.

#### Scenario: Display duration

- **GIVEN** a span has a `duration_ms` value
- **WHEN** the span is displayed in the timeline
- **THEN** durations under 1000ms are shown as "Xms" (e.g., "42ms")
- **AND** durations 1000ms or over are shown as "X.Xs" (e.g., "1.5s")

#### Scenario: No duration

- **GIVEN** a span has no `duration_ms` value (null)
- **WHEN** the span is displayed in the timeline
- **THEN** the duration column shows "-" or is empty
