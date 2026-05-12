## ADDED Requirements

### Requirement: Incident schema
The system SHALL store incidents in a dedicated `incidents` table with the following fields: account_id (FK to accounts), fingerprint (string, max 255 chars, caller-provided), title (string), severity (enum: info, warning, critical), source (string), status (enum: resolved, unresolved), muted (boolean, default false), last_occurrence_at (utc_datetime), metadata (JSONB map), and issue_id (FK to issues, unique). Each incident SHALL have many incident_occurrences.

#### Scenario: Incident created with all fields
- **WHEN** a new incident is reported with fingerprint, title, severity, source, and metadata
- **THEN** the system creates an incident record with the provided fields
- **AND** status defaults to `:unresolved` and muted defaults to `false`
- **AND** account_id is set from the validated project/account
- **AND** last_occurrence_at is set to the current time

#### Scenario: Fingerprint uniqueness scoped to account
- **WHEN** an incident is created with a fingerprint that already exists within the same account
- **THEN** the system treats it as a duplicate and adds an occurrence instead
- **AND** a different account MAY have an incident with the same fingerprint

### Requirement: Incident occurrence schema
The system SHALL store incident occurrences in a dedicated `incident_occurrences` table with: incident_id (FK to incidents), context (JSONB map), and inserted_at (utc_datetime, immutable). Occurrences SHALL NOT have an updated_at field.

#### Scenario: Occurrence recorded for incident
- **WHEN** an incident is reported (new or existing)
- **THEN** an incident_occurrence is created with the provided context
- **AND** the occurrence is immutable after creation

### Requirement: Report incident with fingerprint dedup
The system SHALL provide a `report_incident/5` function that accepts account, user, project_id, incident_attrs, and occurrence_attrs. `incident_attrs` MAY include `reopen_window_hours`; when omitted, the function SHALL use a default of 24 hours. The function SHALL use a PostgreSQL advisory lock on `{account_id, fingerprint}` to prevent race conditions.

#### Scenario: New incident (fingerprint not found)
- **WHEN** `report_incident/5` is called with a fingerprint not matching any existing incident in the account
- **THEN** the system creates a new issue of type `:incident` with the incident's title
- **AND** creates a new incident record linked to that issue
- **AND** creates the first incident_occurrence
- **AND** returns `{:ok, incident, :created}`

#### Scenario: Existing incident with open issue (add occurrence)
- **WHEN** `report_incident/5` is called with a fingerprint matching an existing incident
- **AND** the linked issue has status `:new` or `:in_progress`
- **THEN** the system adds a new incident_occurrence
- **AND** updates `last_occurrence_at` on the incident
- **AND** returns `{:ok, incident, :occurrence_added}`

#### Scenario: Existing incident with recently archived issue (reopen)
- **WHEN** `report_incident/5` is called with a fingerprint matching an existing incident
- **AND** the linked issue has status `:archived`
- **AND** the issue was archived within the provided `reopen_window_hours` (default: 24)
- **THEN** the system reopens the issue (sets status to `:in_progress`)
- **AND** sets the incident status to `:unresolved`
- **AND** adds a new incident_occurrence
- **AND** updates `last_occurrence_at` on the incident
- **AND** returns `{:ok, incident, :reopened}`

#### Scenario: Existing incident with old archived issue (create new)
- **WHEN** `report_incident/5` is called with a fingerprint matching an existing incident
- **AND** the linked issue has status `:archived`
- **AND** the issue was archived outside the `reopen_window_hours` window
- **THEN** the system creates a new issue of type `:incident`
- **AND** updates the incident to point at the new issue
- **AND** sets the incident status to `:unresolved`
- **AND** adds a new incident_occurrence
- **AND** returns `{:ok, incident, :created}`

#### Scenario: Project not found
- **WHEN** `report_incident/5` is called with a project_id that does not belong to the account
- **THEN** the system returns `{:error, :project_not_found}`

### Requirement: Resolve incident
The system SHALL provide a `resolve_incident/2` function that marks an incident as resolved and archives the linked issue.

#### Scenario: Resolve an open incident
- **WHEN** `resolve_incident/2` is called with an unresolved incident
- **THEN** the incident status is set to `:resolved`
- **AND** the linked issue status is set to `:archived`

#### Scenario: Resolve an already-resolved incident
- **WHEN** `resolve_incident/2` is called with an already-resolved incident
- **THEN** the function returns `{:ok, incident}` without changes

### Requirement: Incident API endpoints
The system SHALL expose REST API endpoints for incident management at `/api/v1/incidents`.

#### Scenario: Report incident via API
- **WHEN** POST `/api/v1/incidents` with valid fingerprint, title, severity, source, project_id, and optional metadata and context
- **THEN** the system calls `report_incident/5` and returns the incident
- **AND** HTTP status is 201 for new incidents, 200 for occurrence additions and reopens
- **AND** the endpoint requires `incidents:write` scope

#### Scenario: List incidents
- **WHEN** GET `/api/v1/incidents` with optional status, severity, muted, and source filters
- **THEN** the system returns paginated incidents for the authenticated account
- **AND** results SHALL include `meta` with `page`, `per_page`, `total`, and `total_pages`
- **AND** the endpoint requires `incidents:read` scope

#### Scenario: Get incident detail
- **WHEN** GET `/api/v1/incidents/:id`
- **THEN** the system returns the incident with paginated occurrences
- **AND** the endpoint requires `incidents:read` scope

#### Scenario: Update incident muting
- **WHEN** PATCH `/api/v1/incidents/:id` with a muted field
- **THEN** the system updates the incident's muted value
- **AND** the endpoint requires `incidents:write` scope

#### Scenario: Reject incident status update
- **WHEN** PATCH `/api/v1/incidents/:id` includes a status field
- **THEN** the system rejects the request with 400
- **AND** the incident status and linked issue status remain unchanged

#### Scenario: Incident not found
- **WHEN** any GET or PATCH request targets a non-existent or other-account incident
- **THEN** the system returns 404
