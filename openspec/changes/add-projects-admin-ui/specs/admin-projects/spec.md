# admin-projects

## Purpose

Dashboard UI for managing projects within an account, including project prefix configuration for human-readable issue identifiers.

---

## ADDED Requirements

### Requirement: Projects List View
The system SHALL allow users to view a list of projects in the dashboard.

#### Scenario: User views projects list
- **WHEN** authenticated user navigates to `/dashboard/:account_slug/projects`
- **THEN** page displays all projects belonging to the current account
- **AND** each project shows: name, prefix, issue count, and created date
- **AND** projects are sorted alphabetically by name

#### Scenario: User with no projects sees empty state
- **WHEN** authenticated user navigates to `/dashboard/:account_slug/projects`
- **AND** account has no projects
- **THEN** page displays empty state with terminal aesthetic
- **AND** empty state includes "New Project" call-to-action (if user has write access)

---

### Requirement: Project Creation
The system SHALL allow users with write access to create projects.

#### Scenario: User creates project with valid data
- **WHEN** authenticated user with write access navigates to `/dashboard/:account_slug/projects/new`
- **AND** user enters valid name and prefix
- **AND** user submits the form
- **THEN** project is created in the database
- **AND** user is redirected to the projects list
- **AND** success message is displayed

#### Scenario: User creates project with duplicate prefix
- **WHEN** authenticated user submits project form
- **AND** prefix is already used by another project in the same account
- **THEN** form displays validation error
- **AND** project is not created

#### Scenario: User without write access cannot create projects
- **WHEN** authenticated user without write access views the projects list
- **THEN** "New Project" button is not displayed
- **AND** navigating directly to `/new` redirects to projects list

---

### Requirement: Project Details View and Edit
The system SHALL allow users to view and edit project details.

#### Scenario: User views project details
- **WHEN** authenticated user clicks on a project in the list
- **THEN** user is navigated to `/dashboard/:account_slug/projects/:id`
- **AND** page displays project name, prefix, description, issue count
- **AND** page displays list of recent issues from the project

#### Scenario: User with write access edits project
- **WHEN** authenticated user with write access edits project fields
- **AND** user submits the form
- **THEN** project is updated in the database
- **AND** success message is displayed

#### Scenario: User without write access views project as read-only
- **WHEN** authenticated user without write access views project details
- **THEN** form fields are disabled
- **AND** save/delete buttons are not displayed

---

### Requirement: Project Deletion
The system SHALL allow users with write access to delete projects.

#### Scenario: User deletes project with no issues
- **WHEN** authenticated user with write access clicks delete on a project
- **AND** project has no issues
- **AND** user confirms deletion
- **THEN** project is deleted from the database
- **AND** user is redirected to projects list
- **AND** success message is displayed

#### Scenario: User attempts to delete project with issues
- **WHEN** authenticated user with write access clicks delete on a project
- **AND** project has existing issues
- **THEN** confirmation dialog warns that N issues will also be deleted
- **AND** user must confirm to proceed

---

### Requirement: Sidebar Navigation Projects Link
The sidebar navigation SHALL include a Projects link.

#### Scenario: Dashboard sidebar shows Projects link
- **WHEN** user views any dashboard page
- **THEN** sidebar displays "Projects" link under "// Workspace" section
- **AND** Projects link appears after Issues link

#### Scenario: Projects link highlights when active
- **WHEN** user is on any projects page
- **THEN** Projects link in sidebar has active styling

---

## MODIFIED Requirements

### Requirement: Project Prefix Field
Projects SHALL have a prefix field for generating human-readable issue identifiers.

#### Scenario: Project prefix is required
- **WHEN** a project is created or updated
- **THEN** prefix field is required
- **AND** prefix must be 1-10 uppercase alphanumeric characters
- **AND** prefix must be unique within the account

#### Scenario: Default prefix is suggested from name
- **WHEN** user enters project name on new project form
- **AND** prefix field is empty
- **THEN** prefix field suggests initials from the project name (e.g., "FruitFly" → "FF")

---

### Requirement: Project Issue Counter
Projects SHALL track an issue counter for auto-incrementing issue numbers.

#### Scenario: Issue counter initializes to 1
- **WHEN** a project is created
- **THEN** issue_counter field defaults to 1

#### Scenario: Issue counter increments when issues are created
- **WHEN** an issue is created in a project
- **THEN** issue receives the current counter value as its number
- **AND** counter is atomically incremented

---

### Requirement: Issue Number Field
Issues SHALL have a number field for human-readable identification.

#### Scenario: Issue receives number on creation
- **WHEN** an issue is created
- **THEN** number field is assigned from project's issue_counter
- **AND** number is unique within the project

#### Scenario: Human-readable issue ID is displayed
- **WHEN** an issue is displayed in the UI
- **THEN** the identifier "{prefix}-{number}" is shown (e.g., "FF-123")
- **AND** this appears in issue lists and detail views
