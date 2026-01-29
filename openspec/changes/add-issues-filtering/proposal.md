# Change: Add Issues List Search and Filtering

## Why
Users need to quickly find specific issues within potentially large lists. Search and filtering by status, type, priority, and project allows users to narrow down results to what they're looking for.

## What Changes
- Add search input for title search
- Add status filter dropdown (new, in_progress, archived)
- Add type filter dropdown (bug, feature_request)
- Add priority filter dropdown (low, medium, high, critical)
- Add project filter dropdown (account-scoped projects)
- Search and filters persist in URL query parameters
- Search and filters combine with pagination

## Impact
- Affected specs: Modifies `dashboard-issues` capability
- Affected code:
  - `app/lib/app_web/live/dashboard/issue_live/index.ex` - Add filter controls and handlers
  - `app/lib/app/tracking.ex` - Filtering already supported by `list_issues/2`
- Dependencies: Requires `add-issues-ui` to be implemented first
