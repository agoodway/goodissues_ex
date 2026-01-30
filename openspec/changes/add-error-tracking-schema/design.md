# Error Tracking Schema Design

## Overview

This document describes the database schema and API design for storing error tracking data associated with Issues.

## Entity Relationship

```
Account
  └── Project
        └── Issue (1:1) ──> Error (1:N) ──> Occurrence (1:N) ──> StacktraceLine
```

## Database Schema

### errors table

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | binary_id | PK | Primary key |
| issue_id | binary_id | FK, unique, not null | 1:1 link to issues |
| kind | string(255) | not null | Error type (e.g., "Elixir.RuntimeError") |
| reason | text | not null | Error message |
| source_line | string(255) | default "-" | File:line or "-" |
| source_function | string(255) | default "-" | Module.function/arity or "-" |
| status | enum | not null, default "unresolved" | :resolved, :unresolved |
| fingerprint | string(64) | not null, indexed | SHA256 hash for deduplication |
| last_occurrence_at | utc_datetime | not null | Updated on each occurrence |
| muted | boolean | not null, default false | Suppress notifications |
| inserted_at | utc_datetime | | |
| updated_at | utc_datetime | | |

**Indexes:**
- unique_index(:errors, [:issue_id])
- index(:errors, [:fingerprint])
- index(:errors, [:status])
- index(:errors, [:last_occurrence_at])

### occurrences table

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | binary_id | PK | Primary key |
| error_id | binary_id | FK, not null | belongs_to errors |
| reason | text | | Occurrence-specific message |
| context | jsonb | default {} | Custom metadata |
| breadcrumbs | string[] | default [] | Ordered list of breadcrumbs |
| inserted_at | utc_datetime | not null | Immutable, no updated_at |

**Indexes:**
- index(:occurrences, [:error_id])
- index(:occurrences, [:error_id, :inserted_at])

### stacktrace_lines table

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | binary_id | PK | Primary key |
| occurrence_id | binary_id | FK, not null | belongs_to occurrences |
| position | integer | not null | 0-indexed order in stacktrace |
| application | string(255) | | Application name |
| module | string(255) | indexed | Module name |
| function | string(255) | indexed | Function name |
| arity | integer | | Argument count |
| file | string(500) | indexed | File path |
| line | integer | | Line number |

**Indexes:**
- index(:stacktrace_lines, [:occurrence_id])
- index(:stacktrace_lines, [:module])
- index(:stacktrace_lines, [:function])
- index(:stacktrace_lines, [:file])

## Fingerprint Deduplication

When an error is reported via API:

1. Compute or receive fingerprint (SHA256 of kind + source_function + normalized reason)
2. Query for existing error with same fingerprint within account scope
3. If found: add occurrence, update last_occurrence_at
4. If not found: create Issue + Error + first Occurrence

This enables automatic grouping of repeated errors.

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | /api/v1/errors | Report error (creates Issue if new fingerprint) |
| GET | /api/v1/errors | List errors with filters (status, muted, fingerprint) |
| GET | /api/v1/errors/:id | Get error with occurrences summary |
| PATCH | /api/v1/errors/:id | Update status or muted flag |
| GET | /api/v1/errors/:id/occurrences | Paginated occurrence list |
| GET | /api/v1/errors/search | Search by stacktrace fields |

## Ecto Associations

```elixir
# Issue schema addition
has_one :error, FF.Tracking.Error

# Error schema
belongs_to :issue, FF.Tracking.Issue
has_many :occurrences, FF.Tracking.Occurrence

# Occurrence schema
belongs_to :error, FF.Tracking.Error
has_many :stacktrace_lines, FF.Tracking.StacktraceLine

# StacktraceLine schema
belongs_to :occurrence, FF.Tracking.Occurrence
```

## Cascade Behavior

- Deleting an Issue cascades to delete its Error
- Deleting an Error cascades to delete its Occurrences
- Deleting an Occurrence cascades to delete its StacktraceLines

## Query Patterns

### Find errors by module
```elixir
from e in Error,
  join: o in assoc(e, :occurrences),
  join: s in assoc(o, :stacktrace_lines),
  where: s.module == ^module_name,
  distinct: true
```

### List errors with occurrence count
```elixir
from e in Error,
  left_join: o in assoc(e, :occurrences),
  group_by: e.id,
  select: {e, count(o.id)}
```
