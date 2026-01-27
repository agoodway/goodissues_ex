# Change: Add Admin Accounts UI

## Why
Administrators need a user interface to manage accounts in the system without relying solely on API endpoints. A web-based admin UI provides better usability for account management tasks including creation, modification, deactivation, and audit trail review.

## What Changes
- Add **Admin Accounts UI** capability: web interface for managing user accounts
- List, view, create, update, and deactivate accounts
- Account search and filtering functionality
- Account activity/audit trail visibility
- Role management for accounts
- Admin-only access control for the UI
- LiveView-based interface for real-time updates

## Impact
- Affected specs: None (new capability)
- Affected code:
  - New LiveView modules: `FFWeb.Admin.AccountLive.Index`, `FFWeb.Admin.AccountLive.Show`, `FFWeb.Admin.AccountLive.New`, `FFWeb.Admin.AccountLive.Edit`
  - New admin layout: `FFWeb.AdminLayout`
  - New context functions for account management
  - New database migrations if account audit tables needed
  - Router updates for `/admin/accounts` routes
  - Admin middleware/authentication checks
