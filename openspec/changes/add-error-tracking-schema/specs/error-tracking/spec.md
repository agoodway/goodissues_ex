# Error Tracking

Capability for storing and querying error data associated with Issues.

## ADDED Requirements

### Requirement: Error Schema

The system MUST store error metadata linked 1:1 with Issues.

#### Scenario: Create error with required fields
- Given an Issue exists
- When an error is created with kind, reason, fingerprint, and last_occurrence_at
- Then the error is associated with the Issue
- And status defaults to :unresolved
- And muted defaults to false

#### Scenario: Unique issue constraint
- Given an Issue already has an associated Error
- When attempting to create another Error for the same Issue
- Then the operation fails with a unique constraint error

#### Scenario: Fingerprint indexing
- Given multiple errors exist with different fingerprints
- When querying by fingerprint
- Then the query uses an index and returns efficiently

### Requirement: Occurrence Schema

The system MUST track individual error instances as immutable occurrences.

#### Scenario: Create occurrence with stacktrace
- Given an Error exists
- When an occurrence is created with reason, context, breadcrumbs, and stacktrace_lines
- Then the occurrence is associated with the Error
- And inserted_at is set to current time
- And the occurrence has no updated_at field

#### Scenario: Occurrence context as JSON
- Given a context map with nested data
- When creating an occurrence with this context
- Then the context is stored as JSONB
- And can be retrieved with the same structure

#### Scenario: Breadcrumbs as array
- Given a list of breadcrumb strings
- When creating an occurrence with breadcrumbs
- Then breadcrumbs are stored as an array of strings
- And order is preserved

### Requirement: Stacktrace Lines Schema

The system MUST store stacktrace frames as individual queryable records.

#### Scenario: Create stacktrace lines with position
- Given an Occurrence exists
- When stacktrace lines are created
- Then each line has a position starting from 0
- And lines can be retrieved in order

#### Scenario: Search by module
- Given stacktrace lines exist for module "MyApp.Worker"
- When searching for errors with stacktrace containing "MyApp.Worker"
- Then matching errors are returned
- And the query uses the module index

#### Scenario: Search by function
- Given stacktrace lines exist for function "perform"
- When searching for errors with stacktrace containing function "perform"
- Then matching errors are returned
- And the query uses the function index

#### Scenario: Search by file
- Given stacktrace lines exist for file "lib/my_app/worker.ex"
- When searching for errors with stacktrace containing that file
- Then matching errors are returned
- And the query uses the file index

### Requirement: Fingerprint Deduplication

The system MUST deduplicate errors based on fingerprint within an account.

#### Scenario: New fingerprint creates Issue and Error
- Given no error exists with fingerprint "abc123..."
- When an error is reported with that fingerprint
- Then a new Issue is created
- And a new Error is created linked to the Issue
- And the first Occurrence is created

#### Scenario: Existing fingerprint adds occurrence
- Given an error exists with fingerprint "abc123..."
- When another error is reported with the same fingerprint
- Then no new Issue is created
- And no new Error is created
- And a new Occurrence is added to the existing Error
- And last_occurrence_at is updated

#### Scenario: Fingerprint scoped to account
- Given Account A has an error with fingerprint "abc123..."
- And Account B has no errors
- When Account B reports an error with fingerprint "abc123..."
- Then a new Issue and Error are created in Account B
- And Account A's error is unaffected

### Requirement: Error Status Management

The system MUST track error resolution status.

#### Scenario: Update error status to resolved
- Given an error with status :unresolved
- When status is updated to :resolved
- Then the error status changes to :resolved
- And updated_at is set

#### Scenario: Mute error
- Given an error with muted false
- When muted is updated to true
- Then the error is marked as muted

### Requirement: Cascade Deletion

The system MUST maintain referential integrity through cascade deletes.

#### Scenario: Delete Issue cascades to Error
- Given an Issue with an associated Error
- When the Issue is deleted
- Then the Error is also deleted

#### Scenario: Delete Error cascades to Occurrences
- Given an Error with multiple Occurrences
- When the Error is deleted
- Then all associated Occurrences are deleted

#### Scenario: Delete Occurrence cascades to StacktraceLines
- Given an Occurrence with multiple StacktraceLines
- When the Occurrence is deleted
- Then all associated StacktraceLines are deleted

### Requirement: Error API Endpoints

The API MUST provide endpoints for error management.

#### Scenario: Report error via POST
- Given valid API credentials
- When POST /api/v1/errors with error data
- Then the error is processed with fingerprint deduplication
- And the response includes the error and issue details

#### Scenario: List errors with filters
- Given multiple errors exist
- When GET /api/v1/errors with status=unresolved
- Then only unresolved errors are returned
- And results are paginated

#### Scenario: Get error with occurrences
- Given an error with multiple occurrences
- When GET /api/v1/errors/:id
- Then the error is returned with occurrence count
- And recent occurrences are included

#### Scenario: Update error status
- Given an error exists
- When PATCH /api/v1/errors/:id with status=resolved
- Then the error status is updated
- And the response reflects the change

#### Scenario: List occurrences paginated
- Given an error with many occurrences
- When GET /api/v1/errors/:id/occurrences with page=2
- Then the second page of occurrences is returned
- And includes stacktrace lines

#### Scenario: Search by stacktrace
- Given errors with various stacktraces
- When GET /api/v1/errors/search with module=MyApp.Worker
- Then errors with matching stacktrace lines are returned
