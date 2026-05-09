## MODIFIED Requirements

### Requirement: Issue List View

The dashboard SHALL provide a list view of all issues within the current account with realtime updates when issues are created or modified.

#### Scenario: Incident issues are displayed and filterable
- **WHEN** the issue list contains issues with type `incident`
- **THEN** each incident issue displays a distinct incident type badge in the list
- **AND** the type filter includes an `incident` option
- **AND** filtering by type `incident` returns only incident issues

### Requirement: Issue Detail View

The dashboard SHALL render issue detail pages for issues with type `incident`.

#### Scenario: Display incident issue detail
- **WHEN** an authenticated user views an issue with type `incident`
- **THEN** the issue detail page displays the issue metadata, including an incident type label and styling
- **AND** the page renders successfully without requiring incident to be a manually creatable issue type

## ADDED Requirements

### Requirement: Project Issue References

The dashboard SHALL render incident issue references anywhere project pages display issue type badges.

#### Scenario: Project detail recent issues show incident type
- **WHEN** a project detail page displays a recent issue with type `incident`
- **THEN** the incident issue renders with an incident type label and styling
- **AND** the page renders successfully alongside existing bug and feature request issues

### Requirement: Manual Issue Creation Type Options

The dashboard SHALL keep incident issue creation system-driven rather than manually selectable.

#### Scenario: Manual issue form excludes incident type
- **WHEN** an authenticated user views the manual issue creation or edit form
- **THEN** the available type options include `bug` and `feature_request`
- **AND** `incident` is not offered as a selectable form option
