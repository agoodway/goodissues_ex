# Add Error Tracking Schema

## Summary

Add error tracking data storage to FruitFly, enabling Issues to be linked with detailed error information including occurrences, stacktraces, and deduplication via fingerprints.

## Motivation

FruitFly currently tracks bugs and feature requests as Issues, but lacks the ability to store structured error data from external error tracking systems or application logs. This proposal adds:

- **Error schema**: Stores error metadata (kind, reason, fingerprint) with 1:1 link to Issues
- **Occurrence schema**: Tracks individual error instances with context and breadcrumbs
- **Stacktrace storage**: Normalized stacktrace lines enabling search by module, function, or file

## Scope

### In Scope
- Database schema for errors, occurrences, and stacktrace_lines tables
- Ecto schemas with associations to Issues
- Context functions for CRUD operations and fingerprint deduplication
- API endpoints for error reporting and querying

### Out of Scope
- Integration with external error tracking services (ErrorTracker, Sentry, etc.)
- Real-time error notifications or alerting
- Error aggregation dashboards or analytics

## Approach

Use a **fully normalized schema** with three new tables:

1. **errors**: 1:1 with issues, stores error metadata and fingerprint for deduplication
2. **occurrences**: Many per error, immutable records of each error instance
3. **stacktrace_lines**: Many per occurrence, enables searching by module/function/file

This approach:
- Maintains consistency with existing normalized database patterns
- Supports efficient queries on stacktrace fields (indexed module, function, file)
- Allows pagination of occurrences for high-volume errors

## Success Criteria

- Errors can be created via API with fingerprint deduplication
- Existing fingerprint updates error's last_occurrence_at and adds new occurrence
- Stacktrace lines are searchable by module, function, and file
- All operations respect account-scoped multi-tenancy
