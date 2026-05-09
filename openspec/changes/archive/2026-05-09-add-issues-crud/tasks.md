# Tasks

## 1. Routes
- [x] 1.1 Add `/issues/new` route for issue creation
- [x] 1.2 Add `/issues/:id` route for issue detail view
- [x] 1.3 Add `/issues/:id/edit` route for issue editing (if using separate page)

## 2. Issue Detail View
- [x] 2.1 Create `IssueLive.Show` module for detail view
- [x] 2.2 Display all issue fields (title, description, status, type, priority, project, submitter, dates)
- [x] 2.3 Add edit button for authorized users
- [x] 2.4 Add delete button for authorized users
- [x] 2.5 Handle 404 for non-existent or unauthorized issues

## 3. Issue Creation
- [x] 3.1 Create `IssueLive.New` module with creation form
- [x] 3.2 Create `IssueLive.FormComponent` for reusable form
- [x] 3.3 Add project selection dropdown (account-scoped projects)
- [x] 3.4 Implement form validation and error display
- [x] 3.5 Redirect to issue detail on success
- [x] 3.6 Add "New Issue" button to issues list header

## 4. Issue Editing
- [x] 4.1 Add edit action to `IssueLive.Show` (modal or page)
- [x] 4.2 Reuse `IssueLive.FormComponent` for edit form
- [x] 4.3 Handle validation errors
- [x] 4.4 Show success message on update

## 5. Issue Deletion
- [x] 5.1 Add delete handler to `IssueLive.Show`
- [x] 5.2 Show confirmation dialog before deletion
- [x] 5.3 Redirect to issues list after deletion
- [x] 5.4 Show success message

## 6. Testing
- [x] 6.1 Add LiveView tests for show view
- [x] 6.2 Add LiveView tests for create flow
- [x] 6.3 Add LiveView tests for edit flow
- [x] 6.4 Add LiveView tests for delete flow
- [x] 6.5 Add tests for authorization (non-authorized users)
