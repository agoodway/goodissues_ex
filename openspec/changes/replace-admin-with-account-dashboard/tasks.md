# Tasks: Replace Admin with Account Dashboard

## Phase 1: Schema and Scope Changes ✅

- [x] **1.1** Extend `FF.Accounts.Scope` struct to include `account`, `account_user`, and `accounts` fields
- [x] **1.2** Add scope helper functions: `can_manage_account?/1`, `can_view_account?/1`, `has_account?/1`, `is_owner?/1`, `with_account/4`
- [x] **1.3** Add `Accounts.get_user_accounts/1` to fetch all accounts a user belongs to with roles
- [x] **1.4** Add `Accounts.get_account_user_by_id/2` to fetch a user's membership for a specific account
- [x] **1.5** Write unit tests for new Scope helpers
- [x] **1.6** Write unit tests for new Accounts functions

## Phase 2: Authentication and Account Selection ✅

- [x] **2.1** Create `FFWeb.UserAuth.on_mount(:ensure_account_selected)` callback
- [x] **2.2** Implement account selection logic (session-based, with fallback to first account)
- [x] **2.3** Add `DashboardController.switch_account/2` action for account switching
- [x] **2.4** Write integration tests for account selection flow
- [x] **2.5** Write integration tests for account switching

## Phase 3: Rename Admin to Dashboard ✅

- [x] **3.1** Create `/dashboard` route scope in router (parallel to `/admin` temporarily)
- [x] **3.2** Copy `lib/app_web/live/admin/` directory to `lib/app_web/live/dashboard/`
- [x] **3.3** Update module namespaces from `FFWeb.Admin.*` to `FFWeb.Dashboard.*`
- [x] **3.4** Create `FFWeb.Layouts.dashboard/1` layout function
- [x] **3.5** Update all route helpers from `~p"/admin/*"` to `~p"/dashboard/*"`
- [x] **3.6** Update tests to use new route paths and module names

## Phase 4: Account Switcher Component ✅

- [x] **4.1** Create `account_switcher/1` component in Layouts module
- [x] **4.2** Integrate account switcher into dashboard layout sidebar
- [x] **4.3** Style account switcher dropdown (account name, role badge)
- [x] **4.4** Shows current account with check icon, other accounts as switch options

## Phase 5: Scope Dashboard Data ✅

- [x] **5.1** Update `AccountLive.Index` to show only current account settings (remove list view)
- [x] **5.2** Add role-based permission checks using `Scope.can_manage_account?/1`
- [x] **5.3** Removed unnecessary routes (`:new`, `:show` for accounts in dashboard)
- [x] **5.4** Add `Accounts.list_account_api_keys/2` for account-scoped API key listing
- [x] **5.5** Add `Accounts.get_account_api_key/2` and `get_account_api_key!/2` for scoped retrieval
- [x] **5.6** Update `ApiKeyLive.Index` to scope API keys to current account
- [x] **5.7** Update `ApiKeyLive.New` to create keys for current account membership only
- [x] **5.8** Update `ApiKeyLive.Show` to verify API key belongs to current account
- [x] **5.9** Add permission checks for create/revoke operations (owner/admin only)
- [x] **5.10** Write integration tests for dashboard API key views

## Phase 6: Remove is_admin Flag ✅

- [x] **6.1** Remove `/admin` routes from router
- [x] **6.2** Remove `Layouts.admin/1` function
- [x] **6.3** Remove `ensure_admin` on_mount callback from `UserAuth`
- [x] **6.4** Delete `FFWeb.Plugs.AdminAuth` plug
- [x] **6.5** Remove `is_admin` field from `User` schema
- [x] **6.6** Create migration to drop `is_admin` column from users table
- [x] **6.7** Remove `admin_user_fixture` from test fixtures
- [x] **6.8** Remove `register_and_log_in_admin_user` from `conn_case.ex`
- [x] **6.9** Remove admin LiveView modules (`lib/app_web/live/admin/`)
- [x] **6.10** Remove admin LiveView tests (`test/app_web/live/admin/`)

## Phase 7: Cleanup and Documentation ✅

- [x] **7.1** Verify no remaining references to `is_admin` across codebase (only migrations)
- [x] **7.2** Run full test suite - all 200 tests pass (1 pre-existing failure unrelated)
- [x] **7.3** Add `register_and_log_in_user_with_account` helper to `conn_case.ex`
- [x] **7.4** Update tasks.md with completion status

## Summary

All phases completed successfully. The application now uses an account-scoped dashboard model:

- **Users** access the dashboard at `/dashboard`
- **Account selection** happens automatically (first account or session-stored preference)
- **Account switching** via dropdown in sidebar
- **Permissions** based on role within account (owner/admin can manage, member has read-only)
- **API keys** scoped to current account
- **No global admin** - all permissions are account-based

## Test Coverage

- 200 tests passing
- 1 pre-existing failure in user_registration_controller_test.exs (flash message mismatch)
