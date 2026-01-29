## ADDED Requirements

### Requirement: Issue List Search and Filtering
The dashboard SHALL provide search and filtering capabilities for the issues list.

#### Scenario: Search issues
- **WHEN** a user enters a search term in the search box
- **THEN** the issue list is filtered to show issues with matching titles
- **AND** pagination updates to reflect filtered results

#### Scenario: Filter by status
- **WHEN** a user selects a status filter (new, in_progress, archived, all)
- **THEN** the issue list is filtered to show only matching issues
- **AND** pagination updates to reflect filtered results

#### Scenario: Filter by type
- **WHEN** a user selects a type filter (bug, feature_request, all)
- **THEN** the issue list is filtered to show only matching issues
- **AND** pagination updates to reflect filtered results

#### Scenario: Filter by priority
- **WHEN** a user selects a priority filter (low, medium, high, critical, all)
- **THEN** the issue list is filtered to show only matching issues
- **AND** pagination updates to reflect filtered results

#### Scenario: Filter by project
- **WHEN** a user selects a project filter
- **THEN** the issue list is filtered to show only issues in that project
- **AND** pagination updates to reflect filtered results

#### Scenario: Combined search and filters
- **WHEN** a user applies both search and filter criteria
- **THEN** results match all applied criteria
- **AND** pagination updates to reflect filtered results
