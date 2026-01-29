# Change: Add Realtime Issue List Updates via PubSub

## Why
Currently, the issues list view only refreshes when users manually navigate or reload the page. When issues are created or updated via the API, users viewing the admin dashboard don't see these changes until they refresh. This creates a stale view and requires manual refreshes to see new issues.

## What Changes
- Modify `Tracking.create_issue/3` and `Tracking.update_issue/2` to broadcast PubSub messages on issue creation/updates
- Subscribe to account-specific PubSub topics in `IssueLive.Index` LiveView
- Handle incoming PubSub messages to automatically update the displayed issue list
- Add toast notifications for new issues created via API

## Impact
- **Affected specs**: `issues-ui` (MODIFIED)
- **Affected code**:
  - `lib/app/tracking.ex` - PubSub broadcasting functions
  - `lib/app_web/live/dashboard/issue_live/index.ex` - Subscribe and handle PubSub events
  - `test/app/tracking_test.exs` - Tests for PubSub broadcasting
  - `test/app_web/live/dashboard/issue_live/issue_index_test.exs` - Tests for realtime updates
