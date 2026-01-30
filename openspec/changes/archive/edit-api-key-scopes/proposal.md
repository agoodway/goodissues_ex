# Change: Edit API Key Scopes

## Why
Users need the ability to modify API key scopes after creation without having to revoke and recreate the key. This provides better key lifecycle management and allows admins to adjust access permissions dynamically while maintaining the same API key token.

## What Changes
- Add edit functionality to dashboard API keys view to allow modifying scopes
- Add `update_api_key/2` function to Accounts context
- Create `ApiKeyLive.Edit` LiveView for editing scopes
- Add edit button to API key show page
- Add route for `/dashboard/:account_slug/api-keys/:id/edit`
- Use checkboxes for selecting scopes (user-friendly selection interface)
- Ensure only users with owner/admin role can edit API keys
- Preserve other API key attributes (name, type, expires_at) when updating scopes

## Impact
- Affected specs: dashboard-api-keys (new capability)
- Affected code:
  - `FF.Accounts` context: add `update_api_key/2` function
  - `FFWeb.Dashboard.ApiKeyLive.Show`: add edit button/link
  - `FFWeb.Dashboard.ApiKeyLive.Edit`: new LiveView module
  - `FFWeb.Router`: add edit route for API keys
  - Existing API key schema already supports scopes field (no migration needed)
