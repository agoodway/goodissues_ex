# Change: Update Issue Detail View with Error Data

## Why

Issues can now be linked to error tracking data (errors, occurrences, stacktraces) via the `add-error-tracking-schema` change. The issue detail view needs to display this error information so users can see error context when viewing an issue.

## What Changes

- Add error summary section to issue detail view (when error exists)
- Display error metadata: kind, reason, status, occurrence count, last occurrence time
- Show collapsible stacktrace from the latest occurrence
- Add controls to toggle muted flag and change error status (resolved/unresolved)
- Preload error data with occurrence count when loading issue

## Impact

- Affected specs: `issues-ui`
- Affected code:
  - `lib/app_web/live/dashboard/issue_live/show.ex` - Add error section to render
  - `lib/app/tracking.ex` - May need query adjustments for preloading
