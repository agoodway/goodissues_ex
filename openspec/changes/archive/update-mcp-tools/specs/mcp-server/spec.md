## ADDED Requirements

### Requirement: Account Scoping
All MCP tools SHALL scope data access to the account associated with the authenticated API key (`api_key.account_user.account`). Tools MUST NOT allow access to resources belonging to other accounts.

#### Scenario: Account isolation
- **WHEN** client authenticates with API key belonging to Account A
- **THEN** all queries are scoped to Account A only
- **AND** resources from other accounts are never returned

---

### Requirement: Projects List Tool
The MCP server SHALL provide a `projects_list` tool that lists projects in the authenticated account.

#### Scenario: List projects with pagination
- **WHEN** client calls `projects_list` with page and per_page parameters
- **THEN** return paginated list of projects with id, name, description, prefix, inserted_at, updated_at
- **AND** return pagination metadata (page, per_page, total_count, total_pages, has_next, has_prev)
- **AND** only projects belonging to the API key's account are returned

#### Scenario: Scope enforcement
- **WHEN** API key lacks `projects:read` scope
- **THEN** return error "Insufficient permissions. Required scope: projects:read"

---

### Requirement: Projects Get Tool
The MCP server SHALL provide a `projects_get` tool that retrieves a specific project by ID.

#### Scenario: Get project by ID
- **WHEN** client calls `projects_get` with valid project ID
- **THEN** return project with id, name, description, prefix, inserted_at, updated_at

#### Scenario: Project not found
- **WHEN** client calls `projects_get` with invalid or non-existent project ID
- **THEN** return error "Resource not found"

#### Scenario: Cross-account access prevented
- **WHEN** client calls `projects_get` with project ID belonging to different account
- **THEN** return error "Resource not found"

---

### Requirement: Issues List Tool
The MCP server SHALL provide an `issues_list` tool that lists issues with filtering and pagination.

#### Scenario: List issues with filters
- **WHEN** client calls `issues_list` with optional filters (project_id, status, type) and pagination
- **THEN** return paginated list of issues with id, title, description, number, type, status, priority, project_id, inserted_at, updated_at
- **AND** return pagination metadata

#### Scenario: Filter by project
- **WHEN** client calls `issues_list` with project_id filter
- **THEN** return only issues belonging to that project

#### Scenario: Filter by status
- **WHEN** client calls `issues_list` with status filter (new, in_progress, archived)
- **THEN** return only issues with matching status

#### Scenario: Filter by type
- **WHEN** client calls `issues_list` with type filter (bug, feature_request)
- **THEN** return only issues with matching type

---

### Requirement: Issues Get Tool
The MCP server SHALL provide an `issues_get` tool that retrieves a specific issue by ID.

#### Scenario: Get issue by ID
- **WHEN** client calls `issues_get` with valid issue ID
- **THEN** return issue with id, title, description, number, type, status, priority, project (with id, name, prefix), inserted_at, updated_at

#### Scenario: Issue not found
- **WHEN** client calls `issues_get` with invalid or non-existent issue ID
- **THEN** return error "Resource not found"

---

### Requirement: Issues Create Tool
The MCP server SHALL provide an `issues_create` tool that creates a new issue.

#### Scenario: Create issue
- **WHEN** client calls `issues_create` with title, type, project_id, and optional description/priority
- **THEN** create issue and return created issue data

#### Scenario: Write scope required
- **WHEN** API key lacks `projects:write` scope
- **THEN** return error "Insufficient permissions. Required scope: projects:write"

#### Scenario: Validation errors
- **WHEN** client calls `issues_create` with invalid data (missing title, invalid type)
- **THEN** return validation error message

---

### Requirement: Issues Update Tool
The MCP server SHALL provide an `issues_update` tool that updates an existing issue.

#### Scenario: Update issue
- **WHEN** client calls `issues_update` with issue ID and fields to update (title, description, status, priority, type)
- **THEN** update issue and return updated issue data

#### Scenario: Write scope required
- **WHEN** API key lacks `projects:write` scope
- **THEN** return error "Insufficient permissions. Required scope: projects:write"

#### Scenario: Issue not found
- **WHEN** client calls `issues_update` with non-existent issue ID
- **THEN** return error "Resource not found"

## REMOVED Requirements

### Requirement: Accounts List Tool
**Reason**: Administrative function not useful for AI assistants working with issues/projects
**Migration**: Use web UI for account management

### Requirement: Accounts Get Tool
**Reason**: Administrative function not useful for AI assistants
**Migration**: Use web UI for account management

### Requirement: Accounts Users List Tool
**Reason**: Administrative function not useful for AI assistants
**Migration**: Use web UI for user management

### Requirement: API Keys List Tool
**Reason**: Security-sensitive administrative function
**Migration**: Use web UI for API key management
