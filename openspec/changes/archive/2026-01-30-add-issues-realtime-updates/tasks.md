## 1. Add PubSub Broadcasting to Tracking Context
- [x] 1.1 Add `broadcast_issue_created/2` private function in `Tracking` module to broadcast `:issue_created` event to `"issues:account:<account_id>"` topic with full issue payload (preloading project)
- [x] 1.2 Modify `create_issue/3` to call `broadcast_issue_created/2` after successful issue creation inside the transaction
- [x] 1.3 Add `broadcast_issue_updated/2` private function in `Tracking` module to broadcast `:issue_updated` event to `"issues:account:<account_id>"` topic with issue payload
- [x] 1.4 Modify `update_issue/2` to call `broadcast_issue_updated/2` after successful issue update
- [x] 1.5 Write test for `broadcast_issue_created/2` to verify message is broadcast with correct topic and payload
- [x] 1.6 Write test for `broadcast_issue_updated/2` to verify message is broadcast with correct topic and payload

## 2. Add PubSub Subscription to Issues List LiveView
- [x] 2.1 Update `IssueLive.Index.mount/3` to subscribe to `"issues:account:#{account_id}"` topic via `Phoenix.PubSub.subscribe(FF.PubSub, ...)`
- [x] 2.2 Add `handle_info({:issue_created, issue_data}, socket)` function to handle new issue creation events
- [x] 2.3 Implement logic in `:issue_created` handler to increment total count and show toast notification
- [x] 2.4 Implement optional logic to add issue to current page if it matches filters (not required for MVP) - Skipped (not required for MVP per design doc)
- [x] 2.5 Add `handle_info({:issue_updated, issue_data}, socket)` function to handle issue update events
- [x] 2.6 Implement logic in `:issue_updated` handler to find and update the issue in `@issues` list or remove it if it no longer matches filters
- [x] 2.7 Add tests for LiveView to verify subscription is established on mount
- [x] 2.8 Add tests for `:issue_created` handler to verify total count increment and toast notification
- [x] 2.9 Add tests for `:issue_updated` handler to verify issue is updated in the list

## 3. Add Toast Notification Component
- [x] 3.1 Create `toast_component.ex` in `lib/app_web/live/components/` if it doesn't exist - Using existing flash system which displays as toast
- [x] 3.2 Add toast container to dashboard layout if not already present - Already present in layouts.ex as `flash_group`
- [x] 3.3 Implement `show_toast/3` helper function in LiveView to trigger toast notifications - Using `put_flash/3` which works with existing toast-style flash
- [x] 3.4 Style toast notifications to match existing terminal aesthetic - Existing flash component already styled appropriately

## 4. Testing & Validation
- [x] 5.1 Run `mix test test/app/tracking_test.exs` to verify PubSub broadcasting tests pass
- [x] 5.2 Run `mix test test/app_web/live/dashboard/issue_live_test.exs` to verify realtime LiveView tests pass
- [x] 5.3 Manual test: Open issues list in two browser windows, create issue via API in one, verify toast appears in other
- [x] 5.4 Manual test: Update issue status via API, verify list updates in admin UI without refresh
- [x] 5.5 Run `mix precommit` to ensure all linters and type checks pass

## 6. Documentation
- [x] 6.1 Add `@moduledoc` comments to `broadcast_issue_created/2` and `broadcast_issue_updated/2` explaining topic format and payload structure - Added to module-level @moduledoc and added public `issues_topic/1` function with @doc
- [x] 6.2 Add inline comments in `IssueLive.Index` explaining subscription and event handling logic - Added comments for handle_info functions
- [x] 6.3 Update AGENTS.md or project documentation if needed to note realtime behavior - Not needed, functionality is self-contained
