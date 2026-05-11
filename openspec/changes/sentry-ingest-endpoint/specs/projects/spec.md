## MODIFIED Requirements

### Requirement: Project Data Model
The system SHALL store projects with the following fields.

#### Scenario: Required fields
- **WHEN** a project is created
- **THEN** it MUST have an id (UUID), name (string), and account_id (foreign key)
- **AND** timestamps (inserted_at, updated_at) are automatically set
- **AND** a `sentry_id` (integer) SHALL be auto-assigned, unique within the account

#### Scenario: Optional fields
- **WHEN** a project is created or updated
- **THEN** it MAY have a description (text)

## ADDED Requirements

### Requirement: Sentry Project ID
Each project SHALL have a numeric `sentry_id` for use in Sentry DSN URLs.

#### Scenario: Auto-assignment on creation
- **WHEN** a project is created
- **THEN** a `sentry_id` integer SHALL be automatically assigned
- **AND** the value SHALL be the next sequential integer within the account (starting from 1)
- **AND** the value SHALL be immutable after creation

#### Scenario: Uniqueness within account
- **WHEN** multiple projects exist within the same account
- **THEN** each project SHALL have a unique `sentry_id` within that account
- **AND** projects in different accounts MAY have the same `sentry_id` value

#### Scenario: Project lookup by sentry_id
- **WHEN** the Sentry ingest endpoint receives a request with a numeric project ID in the URL path
- **THEN** the system SHALL resolve the project by `sentry_id` within the authenticated account

### Requirement: DSN Generation
The system SHALL compute a Sentry-compatible DSN for each project.

#### Scenario: DSN format
- **WHEN** a DSN is generated for a project
- **THEN** it SHALL follow the format `https://{api_key_token}@{host}/{sentry_id}`
- **AND** the SDK SHALL be able to parse this into `POST https://{host}/api/{sentry_id}/envelope/`

#### Scenario: DSN in API response
- **WHEN** a project is retrieved via the REST API
- **THEN** the response SHALL include the `sentry_id` field
- **AND** the DSN MAY be computed client-side from `sentry_id` + API key + host
