## ADDED Requirements

### Requirement: Issue Management
The system SHALL provide CRUD operations for issues scoped to projects within accounts.

#### Scenario: Create issue
- **WHEN** authenticated user with write access sends POST to `/api/v1/issues` with valid data
- **THEN** issue is created within the specified project
- **AND** submitter_id is set to the current user
- **AND** response includes issue details with all fields

#### Scenario: Create issue with optional submitter email
- **WHEN** authenticated user sends POST to `/api/v1/issues` with submitter_email
- **THEN** issue is created with both submitter_id (current user) and submitter_email stored

#### Scenario: List issues
- **WHEN** authenticated user sends GET to `/api/v1/issues`
- **THEN** response includes all issues from projects in the user's current account

#### Scenario: List issues filtered by project
- **WHEN** authenticated user sends GET to `/api/v1/issues?project_id=:id`
- **THEN** response includes only issues belonging to that project

#### Scenario: List issues filtered by status
- **WHEN** authenticated user sends GET to `/api/v1/issues?status=:status`
- **THEN** response includes only issues with the specified status

#### Scenario: List issues filtered by type
- **WHEN** authenticated user sends GET to `/api/v1/issues?type=:type`
- **THEN** response includes only issues with the specified type

#### Scenario: Get issue by ID
- **WHEN** authenticated user sends GET to `/api/v1/issues/:id`
- **AND** issue's project belongs to user's current account
- **THEN** response includes issue details

#### Scenario: Get issue from different account
- **WHEN** authenticated user sends GET to `/api/v1/issues/:id`
- **AND** issue's project belongs to a different account
- **THEN** response is 404 Not Found

#### Scenario: Update issue
- **WHEN** authenticated user with write access sends PATCH to `/api/v1/issues/:id`
- **AND** issue's project belongs to user's current account
- **THEN** issue is updated with provided fields
- **AND** response includes updated issue details

#### Scenario: Update issue status to archived
- **WHEN** authenticated user updates issue status to `archived`
- **THEN** archived_at timestamp is set to current time

#### Scenario: Update issue status from archived
- **WHEN** authenticated user updates issue status from `archived` to another status
- **THEN** archived_at timestamp is cleared

#### Scenario: Delete issue
- **WHEN** authenticated user with write access sends DELETE to `/api/v1/issues/:id`
- **AND** issue's project belongs to user's current account
- **THEN** issue is deleted
- **AND** response is 204 No Content

### Requirement: Issue Data Model
The system SHALL store issues with the following fields.

#### Scenario: Required fields
- **WHEN** an issue is created
- **THEN** it MUST have:
  - id (UUID)
  - title (string, max 255 chars)
  - type (enum: bug, feature_request)
  - status (enum: new, in_progress, archived) defaulting to `new`
  - priority (enum: low, medium, high, critical) defaulting to `medium`
  - project_id (foreign key to projects)
  - submitter_id (foreign key to users)
  - timestamps (inserted_at, updated_at)

#### Scenario: Optional fields
- **WHEN** an issue is created or updated
- **THEN** it MAY have:
  - description (text)
  - submitter_email (string, for external tracking)
  - resolved_at (datetime, when issue was resolved)
  - archived_at (datetime, when issue was archived)

### Requirement: Issue Type Enum
The system SHALL support the following issue types.

#### Scenario: Bug type
- **WHEN** issue type is `bug`
- **THEN** it represents a defect or error in the system

#### Scenario: Feature request type
- **WHEN** issue type is `feature_request`
- **THEN** it represents a request for new functionality

### Requirement: Issue Status Enum
The system SHALL support the following issue statuses.

#### Scenario: New status
- **WHEN** issue status is `new`
- **THEN** it represents an issue that has not been triaged or started

#### Scenario: In progress status
- **WHEN** issue status is `in_progress`
- **THEN** it represents an issue actively being worked on

#### Scenario: Archived status
- **WHEN** issue status is `archived`
- **THEN** it represents an issue that is closed or no longer relevant
- **AND** archived_at timestamp is set

### Requirement: Issue Priority Enum
The system SHALL support the following priority levels.

#### Scenario: Low priority
- **WHEN** issue priority is `low`
- **THEN** it represents a minor issue that can be addressed when convenient

#### Scenario: Medium priority
- **WHEN** issue priority is `medium`
- **THEN** it represents a standard priority issue (default)

#### Scenario: High priority
- **WHEN** issue priority is `high`
- **THEN** it represents an important issue requiring prompt attention

#### Scenario: Critical priority
- **WHEN** issue priority is `critical`
- **THEN** it represents an urgent issue requiring immediate attention

### Requirement: Issue OpenAPI Schema
The system SHALL provide OpenAPI documentation for issue endpoints.

#### Scenario: Schema definitions
- **WHEN** OpenAPI spec is requested
- **THEN** it includes IssueRequest, IssueResponse, and enum schemas
- **AND** all endpoints are documented with request/response examples
- **AND** filter parameters are documented for list endpoint
