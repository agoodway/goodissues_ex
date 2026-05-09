# Proposal: Replace Admin with Account Dashboard

## Change ID
`replace-admin-with-account-dashboard`

## Summary
Remove the global `is_admin` flag from users and replace the admin section with an account-scoped dashboard. Any user associated with an account can access the dashboard to manage their account(s) based on their role within that account (owner/admin/member).

## Motivation
The current implementation uses a global `is_admin` boolean flag on the User schema to gate access to admin functionality. This approach:
- Conflates system administration with account management
- Doesn't leverage the existing account membership and role system (`AccountUser` with `role: [:owner, :admin, :member]`)
- Prevents regular users from managing their own accounts

The change aligns dashboard access with the multi-tenant account model already in place.

## Current State

### User Schema
- `User` has `is_admin: :boolean, default: false`
- Users can belong to multiple accounts via `AccountUser` join table
- `AccountUser` already has roles: `:owner`, `:admin`, `:member`

### Admin Routes
- Routes under `/admin/*` require `is_admin == true`
- `GIWeb.UserAuth.on_mount(:ensure_admin)` checks `user.is_admin`
- `GIWeb.Plugs.AdminAuth` checks `user.is_admin`
- Admin LiveViews manage ALL accounts system-wide

### Affected Files
- `app/lib/app/accounts/user.ex` - has `is_admin` field
- `app/lib/app_web/user_auth.ex` - `ensure_admin` on_mount
- `app/lib/app_web/plugs/admin_auth.ex` - admin plug
- `app/lib/app_web/router.ex` - `/admin` scope
- `app/lib/app_web/live/admin/*` - admin LiveViews
- `app/lib/app_web/components/layouts.ex` - admin layout
- `app/priv/repo/migrations/20260127165749_add_is_admin_to_users.exs` - migration

## Proposed Changes

### 1. Remove `is_admin` from User
- Remove the `is_admin` field from User schema
- Create migration to drop the column

### 2. Rename `/admin` to `/dashboard`
- Change route scope from `/admin` to `/dashboard`
- Update module namespaces from `Admin` to `Dashboard`
- Rename files and directories accordingly

### 3. Scope Dashboard to User's Accounts
- Replace global admin check with account membership check
- Users see only accounts they belong to
- Permissions based on `AccountUser.role`:
  - `owner`/`admin`: full management (create, edit, suspend)
  - `member`: read-only access

### 4. Add Account Switcher
- Add dropdown in dashboard nav for switching between accounts
- Store selected account in session/scope
- Auto-select last used account on dashboard access

### 5. Update Scope Module
- Extend `GI.Accounts.Scope` to include current account context
- Provide helpers for checking account-level permissions

## Out of Scope
- System-wide super-admin functionality (can be added later if needed)
- Changes to API key management (already scoped to AccountUser)
- Account creation from dashboard (users join existing accounts)

## Dependencies
- Existing `AccountUser` role system
- Existing `accounts` and `account_users` tables

## Risks
- **Data Loss**: Existing `is_admin` flags will be lost. Need to ensure any current admins are account owners/admins.
- **Breaking Change**: Routes change from `/admin/*` to `/dashboard/*`.
- **Test Updates**: Significant test fixture and helper changes needed.

## Migration Strategy
1. Before removing `is_admin`, ensure all admin users have appropriate account memberships with `owner` or `admin` role.
2. Run data migration to verify/create account memberships.
3. Deploy route changes.
4. Remove `is_admin` column.
