# Change: Add Admin API Keys UI

## Why
Administrators need a user interface to manage API keys without relying solely on API endpoints. A web-based admin UI provides better visibility and control over API key lifecycle management including creation, viewing details, and revocation.

## What Changes
- Add **Admin API Keys UI** capability: web interface for managing API keys
- List all API keys with filtering by account, status, and type
- View detailed API key information (name, type, scopes, owner, last_used_at, expires_at, status)
- Create new API keys with ability to view the token once on creation
- Revoke existing API keys
- Search/filter API keys by name, account, or user
- Admin-only access control for the UI
- LiveView-based interface for real-time updates
- Integration with existing admin accounts section

## Impact
- Affected specs: None (new capability)
- Affected code:
  - New LiveView modules: `FFWeb.Admin.ApiKeyLive.Index`, `FFWeb.Admin.ApiKeyLive.Show`, `FFWeb.Admin.ApiKeyLive.New`
  - Router updates for `/admin/api-keys` routes
  - Admin middleware/authentication checks (reuse from admin-accounts-ui)
  - Potential additions to Accounts context if needed (list_all_api_keys, get_api_key_details)
