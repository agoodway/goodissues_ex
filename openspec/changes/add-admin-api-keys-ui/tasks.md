## 1. Context Layer
- [ ] 1.1 Review existing FF.Accounts API key functions for admin use
- [ ] 1.2 Add `list_all_api_keys/2` function with filtering support (optional, can build queries in LiveView)
- [ ] 1.3 Add `get_api_key_with_preloads!/1` to fetch API key with account_user preloads
- [ ] 1.4 Write unit tests for new context functions

## 2. Admin Authentication
- [ ] 2.1 Ensure admin authentication middleware exists (re-use from admin-accounts-ui)
- [ ] 2.2 Verify admin-only access control works for new routes
- [ ] 2.3 Write integration tests for admin authentication

## 3. Admin LiveViews - Index
- [ ] 3.1 Create `FFWeb.Admin.ApiKeyLive.Index` LiveView
- [ ] 3.2 Implement API key listing with pagination
- [ ] 3.3 Add filter controls (status, type, account search)
- [ ] 3.4 Add search functionality by name or owner email
- [ ] 3.5 Display API key details table (name, type, owner, account, status, scopes, last_used, expires_at)
- [ ] 3.6 Add action buttons (view details, create new, revoke)

## 4. Admin LiveViews - Show
- [ ] 4.1 Create `FFWeb.Admin.ApiKeyLive.Show` LiveView
- [ ] 4.2 Display full API key details
- [ ] 4.3 Show associated account and user information
- [ ] 4.4 Display activity information (created_at, last_used_at)
- [ ] 4.5 Add revoke action with confirmation
- [ ] 4.6 Handle revoked status display

## 5. Admin LiveViews - Create
- [ ] 5.1 Create `FFWeb.Admin.ApiKeyLive.New` LiveView
- [ ] 5.2 Implement API key creation form (name, type, scopes, expires_at, account_user selection)
- [ ] 5.3 Add form validation and error handling
- [ ] 5.4 Display generated token once on creation (with copy button)
- [ ] 5.5 Redirect to show page after creation
- [ ] 5.6 Warn user that token cannot be retrieved later

## 6. Router Integration
- [ ] 6.1 Add admin API keys routes to router with authentication guard
- [ ] 6.2 Add breadcrumb navigation from admin accounts to API keys
- [ ] 6.3 Ensure routes are properly nested under `/admin`

## 7. Styling
- [ ] 7.1 Style API keys index table with consistent admin design
- [ ] 7.2 Style API key show page with clear sections
- [ ] 7.3 Style API key creation form
- [ ] 7.4 Add status badges (active/revoked)
- [ ] 7.5 Add type badges (public/private) with visual distinction
- [ ] 6.6 Add copy-to-clipboard functionality for tokens
- [ ] 7.7 Add responsive design considerations
- [ ] 7.8 Add confirm modal for revoke action

## 8. Testing
- [ ] 8.1 Write unit tests for new context functions
- [ ] 8.2 Write LiveView tests for index page (listing, filtering, search)
- [ ] 8.3 Write LiveView tests for show page (display details, revoke action)
- [ ] 8.4 Write LiveView tests for create page (form validation, token generation)
- [ ] 8.5 Write integration tests for admin authentication
- [ ] 8.6 Test edge cases (revoked keys, expired keys, no results)

## 9. Documentation
- [ ] 9.1 Document admin access requirements for API key management
- [ ] 9.2 Document API key lifecycle management workflows
- [ ] 9.3 Document token security considerations (display once, cannot be retrieved)
- [ ] 9.4 Update admin UI navigation documentation
