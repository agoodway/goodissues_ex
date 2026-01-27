## 1. Context Layer
- [x] 1.1 Review existing FF.Accounts API key functions for admin use
- [x] 1.2 Add `list_all_api_keys/1` function with filtering support
- [x] 1.3 Add `get_api_key!/1` to fetch API key with account_user preloads
- [x] 1.4 Write unit tests for new context functions

## 2. Admin Authentication
- [x] 2.1 Ensure admin authentication middleware exists (re-use from admin-accounts-ui)
- [x] 2.2 Verify admin-only access control works for new routes
- [x] 2.3 Write integration tests for admin authentication

## 3. Admin LiveViews - Index
- [x] 3.1 Create `FFWeb.Admin.ApiKeyLive.Index` LiveView
- [x] 3.2 Implement API key listing with pagination
- [x] 3.3 Add filter controls (status, type)
- [x] 3.4 Add search functionality by name or owner email
- [x] 3.5 Display API key details table (name, type, owner, account, status, last_used, expires_at)
- [x] 3.6 Add action buttons (view details, create new, revoke)

## 4. Admin LiveViews - Show
- [x] 4.1 Create `FFWeb.Admin.ApiKeyLive.Show` LiveView
- [x] 4.2 Display full API key details
- [x] 4.3 Show associated account and user information
- [x] 4.4 Display activity information (created_at, last_used_at)
- [x] 4.5 Add revoke action with confirmation
- [x] 4.6 Handle revoked status display

## 5. Admin LiveViews - Create
- [x] 5.1 Create `FFWeb.Admin.ApiKeyLive.New` LiveView
- [x] 5.2 Implement API key creation form (name, type, scopes, expires_at, account_user selection)
- [x] 5.3 Add form validation and error handling
- [x] 5.4 Display generated token once on creation (with copy button)
- [x] 5.5 Link to show page after creation
- [x] 5.6 Warn user that token cannot be retrieved later

## 6. Router Integration
- [x] 6.1 Add admin API keys routes to router with authentication guard
- [x] 6.2 Add navigation link from admin sidebar to API keys
- [x] 6.3 Ensure routes are properly nested under `/admin`

## 7. Styling
- [x] 7.1 Style API keys index table with consistent admin design
- [x] 7.2 Style API key show page with clear sections
- [x] 7.3 Style API key creation form
- [x] 7.4 Add status badges (active/revoked)
- [x] 7.5 Add type badges (public/private) with visual distinction
- [x] 7.6 Add copy-to-clipboard functionality for tokens
- [x] 7.7 Add responsive design considerations
- [x] 7.8 Add confirm modal for revoke action (using data-confirm)

## 8. Testing
- [x] 8.1 Write unit tests for new context functions
- [x] 8.2 Write LiveView tests for index page (listing, filtering, search)
- [x] 8.3 Write LiveView tests for show page (display details, revoke action)
- [x] 8.4 Write LiveView tests for create page (form validation, token generation)
- [x] 8.5 Write integration tests for admin authentication
- [x] 8.6 Test edge cases (revoked keys, no results)

## 9. Documentation
- [x] 9.1 Document admin access requirements for API key management
- [x] 9.2 Document API key lifecycle management workflows
- [x] 9.3 Document token security considerations (display once, cannot be retrieved)
- [x] 9.4 Update admin UI navigation documentation
