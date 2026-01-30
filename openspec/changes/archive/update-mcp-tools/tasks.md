## 1. Remove Account Tools
- [x] 1.1 Remove accounts_list, accounts_get, accounts_users_list, api_keys_list component registrations from server.ex
- [x] 1.2 Delete `app/lib/app_web/mcp/tools/accounts/` directory

## 2. Add Account Helper
- [x] 2.1 Add `get_account/1` helper to Base module that extracts account from `api_key.account_user.account`

## 3. Implement Project Tools
- [x] 3.1 Create `app/lib/app_web/mcp/tools/projects/` directory
- [x] 3.2 Implement projects_list.ex tool (pagination, scoped to API key's account via `get_account/1`)
- [x] 3.3 Implement projects_get.ex tool (get by ID, scoped to account)
- [x] 3.4 Register project tools in server.ex

## 4. Implement Issue Tools
- [x] 4.1 Create `app/lib/app_web/mcp/tools/issues/` directory
- [x] 4.2 Implement issues_list.ex tool (filters: project_id, status, type; pagination; scoped to account)
- [x] 4.3 Implement issues_get.ex tool (get by ID with project preload, scoped to account)
- [x] 4.4 Implement issues_create.ex tool (requires projects:write scope, uses API key's user as submitter)
- [x] 4.5 Implement issues_update.ex tool (requires projects:write scope, scoped to account)
- [x] 4.6 Register issue tools in server.ex

## 5. Testing
- [x] 5.1 Verify tools respond correctly with valid API key
- [x] 5.2 Verify scope enforcement (read vs write)
- [x] 5.3 Verify account scoping prevents cross-account access

## 6. Cleanup
- [x] 6.1 Remove hello_world.ex tool (if still present, development only)
- [x] 6.2 Run mix format
