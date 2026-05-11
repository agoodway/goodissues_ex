## MODIFIED Requirements

### Requirement: Error API Endpoints

#### Scenario: Search by stacktrace (MODIFIED)
- Given errors with various stacktraces
- When GET /api/v1/errors/search with module=MyApp.Worker
- Then errors with matching stacktrace lines are returned
- And results SHALL be paginated with accurate `meta` containing `page`, `per_page`, `total`, and `total_pages`
- And the pagination SHALL use DB-level COUNT + LIMIT/OFFSET (not in-memory)
- And errors created from Sentry SDK ingestion SHALL be searchable identically to errors created via the REST API

#### Scenario: List errors with filters (MODIFIED)
- Given multiple errors exist
- When GET /api/v1/errors with status=unresolved
- Then only unresolved errors are returned
- And the response SHALL include `meta` referencing the shared `PaginationMeta` schema
- And errors originating from Sentry SDKs SHALL appear alongside errors created via the REST API with no distinction in response format

## ADDED Requirements

### Requirement: Multi-Source Error Creation
The error tracking system SHALL support error creation from both the REST API and Sentry SDK ingestion with identical deduplication behavior.

#### Scenario: Sentry-originated error matches REST-originated fingerprint
- **WHEN** a Sentry SDK reports an exception whose computed fingerprint matches an Error previously created via the REST API
- **THEN** the system SHALL add an Occurrence to the existing Error
- **AND** NOT create a duplicate Error or Issue

#### Scenario: REST API report matches Sentry-originated fingerprint
- **WHEN** the REST API receives an error report whose fingerprint matches an Error previously created from Sentry ingestion
- **THEN** the system SHALL add an Occurrence to the existing Error
- **AND** NOT create a duplicate Error or Issue
