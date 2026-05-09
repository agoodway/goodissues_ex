# Change: Add Issues Create, Edit, and Delete

## Why
Users need to manage issues through the dashboard UI, not just view them. This enables creating new issues, updating existing issues, and removing issues that are no longer needed.

## What Changes
- Add Issue creation form at `/dashboard/:account_slug/issues/new`
- Add Issue detail view at `/dashboard/:account_slug/issues/:id`
- Add Issue edit functionality (modal or inline)
- Add Issue deletion with confirmation
- Add "New Issue" button to issues list

## Impact
- Affected specs: Modifies `dashboard-issues` capability
- Affected code:
  - `app/lib/app_web/router.ex` - Add new/show routes
  - `app/lib/app_web/live/dashboard/issue_live/new.ex` - Creation form
  - `app/lib/app_web/live/dashboard/issue_live/show.ex` - Detail view with edit/delete
  - `app/lib/app_web/live/dashboard/issue_live/form_component.ex` - Shared form component
- Dependencies: Requires `add-issues-ui` to be implemented first
