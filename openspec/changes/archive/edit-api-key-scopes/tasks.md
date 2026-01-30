## 1. Context Layer
- [x] 1.1 Add `update_api_key/2` function to `FF.Accounts` context
- [x] 1.2 Implement authorization check (only owner/admin of account can edit)
- [x] 1.3 Prevent editing revoked API keys
- [x] 1.4 Handle concurrency with Ecto changesets
- [x] 1.5 Write unit tests for `update_api_key/2`

## 2. Router Integration
- [x] 2.1 Add edit route to `/dashboard/:account_slug/api-keys/:id/edit`
- [x] 2.2 Ensure route is in the `:dashboard` live_session with proper auth
- [x] 2.3 Verify route is nested correctly with account_slug

## 3. Edit LiveView
- [x] 3.1 Create `FFWeb.Dashboard.ApiKeyLive.Edit` module
- [x] 3.2 Implement `mount/3` to verify ownership and load API key
- [x] 3.3 Add form validation event handler
- [x] 3.4 Add save event handler to call `update_api_key/2`
- [x] 3.5 Handle success (redirect to show page with flash message)
- [x] 3.6 Handle errors (display validation errors)
- [x] 3.7 Show appropriate error for unauthorized access attempts
- [x] 3.8 Show appropriate error for revoked key edit attempts

## 4. Update Show Page
- [x] 4.1 Add edit button to `FFWeb.Dashboard.ApiKeyLive.Show`
- [x] 4.2 Only show edit button for active keys
- [x] 4.3 Only show edit button for users with owner/admin role
- [x] 4.4 Link to edit route with proper account_slug

## 5. Form UI
- [x] 5.1 Create edit form with scope checkboxes
- [x] 5.2 Pre-select checkboxes based on current API key scopes
- [x] 5.3 Display list of available scopes as checkboxes
- [x] 5.4 Add checkbox labels that clearly describe each scope's purpose
- [x] 5.5 Add help text explaining what scopes grant access to
- [x] 5.6 Match styling of existing API key forms
- [x] 5.7 Add cancel button to return to show page
- [x] 5.8 Add save button with loading state
- [x] 5.9 Group related scopes visually (e.g., read vs write scopes)

## 6. Testing
- [x] 6.1 Write unit tests for `update_api_key/2` context function
- [x] 6.2 Write LiveView tests for edit page (mount, validation, save)
- [x] 6.3 Test authorization (owner/admin can edit, member cannot)
- [x] 6.4 Test revoked key rejection
- [x] 6.5 Test non-existent key handling
- [x] 6.6 Test form validation for scope formats
- [x] 6.7 Test redirect on success
- [x] 6.8 Test error handling and flash messages

## 7. Documentation
- [x] 7.1 Document the `update_api_key/2` function
- [x] 7.2 Update AGENTS.md if any new patterns are introduced
- [x] 7.3 Add inline comments explaining authorization logic

## 8. Validation
- [x] 8.1 Run `mix format` on all modified files
- [x] 8.2 Run `mix test` for API key tests
- [x] 8.3 Run `mix precommit` and fix any issues
- [x] 8.4 Manual test: Edit scopes of an active key as owner
- [x] 8.5 Manual test: Verify edit button doesn't show for members
- [x] 8.6 Manual test: Verify error when trying to edit revoked key
- [x] 8.7 Manual test: Verify form validation works
