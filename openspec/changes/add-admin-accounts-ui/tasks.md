## 1. Foundation Setup
- [x] 1.1 Create admin authentication/middleware module
- [x] 1.2 Create admin layout module (`FFWeb.AdminLayout`)
- [x] 1.3 Add admin routes to router with authentication guard

## 2. Account Context
- [x] 2.1 Review existing account schema and add missing fields (if needed)
- [x] 2.2 Add account context functions for listing, filtering, searching
- [x] 2.3 Add account context functions for CRUD operations
- [x] 2.4 Add account deactivation/reactivation functions
- [ ] 2.5 Add account audit trail logging (deferred - not in core requirements)

## 3. Admin LiveViews - Index
- [x] 3.1 Create `FFWeb.Admin.AccountLive.Index` LiveView
- [x] 3.2 Implement account listing with pagination
- [x] 3.3 Add search/filter functionality
- [x] 3.4 Add action buttons (view, edit, deactivate)

## 4. Admin LiveViews - Show
- [x] 4.1 Create `FFWeb.Admin.AccountLive.Show` LiveView
- [x] 4.2 Display account details
- [ ] 4.3 Show account activity/audit trail (deferred - not in core requirements)
- [x] 4.4 Add deactivate/activate actions

## 5. Admin LiveViews - Create/Edit
- [x] 5.1 Create `FFWeb.Admin.AccountLive.New` LiveView (combined with FormComponent)
- [x] 5.2 Implement account creation form with validation
- [x] 5.3 Create `FFWeb.Admin.AccountLive.Edit` LiveView (combined with FormComponent)
- [x] 5.4 Implement account update form with validation
- [x] 5.5 Add form error handling and user feedback

## 6. Styling
- [x] 6.1 Style admin layout with consistent design system
- [x] 6.2 Style account tables and lists
- [x] 6.3 Style account forms
- [x] 6.4 Add responsive design considerations

## 7. Testing
- [x] 7.1 Write unit tests for account context functions
- [x] 7.2 Write LiveView tests for index page
- [x] 7.3 Write LiveView tests for show page
- [x] 7.4 Write LiveView tests for create/edit forms
- [x] 7.5 Write integration tests for admin authentication

## 8. Documentation
- [ ] 8.1 Document admin access requirements (not requested)
- [ ] 8.2 Document account management workflows (not requested)
- [ ] 8.3 Update OpenAPI spec if admin API endpoints are added (N/A - no admin API)
