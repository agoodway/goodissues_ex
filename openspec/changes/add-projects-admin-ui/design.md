# Design: Add Projects Admin UI

## Overview

This design covers two related changes:
1. Schema modifications to support human-readable issue identifiers
2. Dashboard UI for project management

## Schema Changes

### Projects Table

Add `prefix` field:
- Type: `string` (max 10 characters)
- Constraints: NOT NULL, uppercase letters/numbers only, unique per account
- Example values: "FF", "BUG", "FEAT", "API"

```
projects
├── id (uuid, PK) - existing
├── name (string) - existing
├── description (text) - existing
├── account_id (uuid, FK) - existing
├── prefix (string, NEW) - human-readable prefix, unique per account
├── issue_counter (integer, NEW) - tracks next issue number, default 1
└── timestamps - existing
```

### Issues Table

Add `number` field:
- Type: `integer`
- Constraints: NOT NULL, unique per project
- Auto-incremented when issue is created

```
issues
├── id (uuid, PK) - existing
├── number (integer, NEW) - sequential number within project
├── ... other fields
└── project_id (uuid, FK) - existing
```

### Issue Identifier

The human-readable identifier is computed: `{project.prefix}-{issue.number}`

Example: Project with prefix "FF" and issue with number 123 → "FF-123"

This is NOT stored in the database—it's computed at read time to allow prefix changes.

## Auto-Increment Strategy

### Option A: Application-level with optimistic locking
```elixir
def create_issue(project, attrs) do
  number = get_next_issue_number(project)
  # Insert with number, retry on conflict
end
```
Pros: Simple, works with read replicas
Cons: Requires retry logic

### Option B: Database trigger
Create a trigger that increments `issue_counter` on the project and assigns `number`.
Pros: Race-condition free
Cons: More complex, harder to test

### Recommended: Option A with `FOR UPDATE`
Use a transaction with `SELECT ... FOR UPDATE` on the project row to get and increment the counter atomically:

```elixir
def create_issue(account, user, attrs) do
  Repo.transaction(fn ->
    project = Repo.one!(
      from p in Project,
      where: p.id == ^project_id,
      lock: "FOR UPDATE"
    )

    number = project.issue_counter

    {:ok, _} = Repo.update(Project.changeset(project, %{issue_counter: number + 1}))

    %Issue{project_id: project.id, submitter_id: user.id, number: number}
    |> Issue.create_changeset(attrs)
    |> Repo.insert!()
  end)
end
```

## UI Design

### Navigation

Add "Projects" to the sidebar under "// Workspace":

```
// Workspace
├── Issues ← existing
└── Projects ← NEW

// Account
├── Settings
└── API Keys
```

### Projects List Page

Path: `/dashboard/:account_slug/projects`

Layout matches existing Issues list with industrial terminal aesthetic:
- Header with icon and project count
- "New Project" button (if user has write access)
- List with columns: NAME, PREFIX, ISSUES, CREATED
- Click row to view/edit project

### Project Show/Edit Page

Path: `/dashboard/:account_slug/projects/:id`

Two-panel layout:
- Left: Project details form (name, prefix, description)
- Right: Recent issues from this project (read-only list)

Editable fields (if user has write access):
- Name (required)
- Prefix (required, uppercase, max 10 chars)
- Description (optional)

Delete button at bottom with confirmation.

### New Project Page

Path: `/dashboard/:account_slug/projects/new`

Simple form:
- Name (required)
- Prefix (required, auto-suggested from name initials)
- Description (optional)

## Migration Strategy

### Step 1: Add columns (non-destructive)
```elixir
alter table(:projects) do
  add :prefix, :string, size: 10
  add :issue_counter, :integer, default: 1
end

alter table(:issues) do
  add :number, :integer
end
```

### Step 2: Backfill data
```elixir
# Generate prefixes from project names
execute """
UPDATE projects
SET prefix = UPPER(SUBSTRING(REGEXP_REPLACE(name, '[^a-zA-Z0-9]', '', 'g'), 1, 3))
WHERE prefix IS NULL
"""

# Assign issue numbers by insertion order within each project
execute """
WITH numbered AS (
  SELECT id, ROW_NUMBER() OVER (PARTITION BY project_id ORDER BY inserted_at) as num
  FROM issues
)
UPDATE issues SET number = numbered.num
FROM numbered WHERE issues.id = numbered.id
"""

# Update issue_counter to next available number
execute """
UPDATE projects
SET issue_counter = COALESCE(
  (SELECT MAX(number) + 1 FROM issues WHERE issues.project_id = projects.id),
  1
)
"""
```

### Step 3: Add constraints
```elixir
alter table(:projects) do
  modify :prefix, :string, null: false
end

alter table(:issues) do
  modify :number, :integer, null: false
end

create unique_index(:projects, [:account_id, :prefix])
create unique_index(:issues, [:project_id, :number])
```

## API Considerations

The human-readable issue ID should be exposed in API responses. This is out of scope for this change but the schema supports it:

```json
{
  "id": "uuid...",
  "key": "FF-123",
  "title": "Bug title",
  ...
}
```

## File Structure

New files:
```
app/lib/app_web/live/dashboard/project_live/
├── index.ex       # List projects
├── show.ex        # View/edit project
├── new.ex         # Create project
└── form_component.ex  # Shared form component (if needed)

app/priv/repo/migrations/
├── YYYYMMDDHHMMSS_add_prefix_to_projects.exs
└── YYYYMMDDHHMMSS_add_number_to_issues.exs
```

Modified files:
```
app/lib/app/tracking/project.ex     # Add prefix, issue_counter fields
app/lib/app/tracking/issue.ex       # Add number field
app/lib/app/tracking.ex             # Update create_issue for auto-increment
app/lib/app_web/components/layouts.ex  # Add Projects to sidebar
app/lib/app_web/router.ex           # Add project routes
```
