## ADDED Requirements

### Requirement: Project Management
The system SHALL provide CRUD operations for projects scoped to accounts.

#### Scenario: Create project
- **WHEN** authenticated user with write access sends POST to `/api/v1/projects` with valid name
- **THEN** project is created within the user's current account
- **AND** response includes project ID, name, description, and timestamps

#### Scenario: List projects
- **WHEN** authenticated user sends GET to `/api/v1/projects`
- **THEN** response includes all projects belonging to the user's current account
- **AND** projects from other accounts are not visible

#### Scenario: Get project by ID
- **WHEN** authenticated user sends GET to `/api/v1/projects/:id`
- **AND** project belongs to user's current account
- **THEN** response includes project details

#### Scenario: Get project from different account
- **WHEN** authenticated user sends GET to `/api/v1/projects/:id`
- **AND** project belongs to a different account
- **THEN** response is 404 Not Found

#### Scenario: Update project
- **WHEN** authenticated user with write access sends PATCH to `/api/v1/projects/:id`
- **AND** project belongs to user's current account
- **THEN** project is updated with provided fields
- **AND** response includes updated project details

#### Scenario: Delete project
- **WHEN** authenticated user with write access sends DELETE to `/api/v1/projects/:id`
- **AND** project belongs to user's current account
- **THEN** project is deleted
- **AND** response is 204 No Content

### Requirement: Project Data Model
The system SHALL store projects with the following fields.

#### Scenario: Required fields
- **WHEN** a project is created
- **THEN** it MUST have an id (UUID), name (string), and account_id (foreign key)
- **AND** timestamps (inserted_at, updated_at) are automatically set

#### Scenario: Optional fields
- **WHEN** a project is created or updated
- **THEN** it MAY have a description (text)

### Requirement: Project OpenAPI Schema
The system SHALL provide OpenAPI documentation for project endpoints.

#### Scenario: Schema definitions
- **WHEN** OpenAPI spec is requested
- **THEN** it includes ProjectRequest and ProjectResponse schemas
- **AND** all endpoints are documented with request/response examples
