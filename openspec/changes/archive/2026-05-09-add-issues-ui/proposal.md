# Change: Add Issues List UI to Dashboard

## Why
Users need a web interface to view issues within their account's projects. Currently issues can only be viewed via the REST API or CLI. Adding a dashboard UI provides a user-friendly way to browse issues.

## What Changes
- Add Issues list view at `/dashboard/:account_slug/issues`
- Update sidebar navigation to include Issues link
- Follow existing dashboard patterns (API Keys UI, industrial terminal aesthetic)

## Impact
- Affected specs: New `dashboard-issues` capability
- Affected code:
  - `app/lib/app_web/router.ex` - Add route
  - `app/lib/app_web/live/dashboard/issue_live/index.ex` - New LiveView module
  - `app/lib/app_web/components/layouts.ex` - Update sidebar navigation
  - `app/lib/app/tracking.ex` - Add paginated list function
