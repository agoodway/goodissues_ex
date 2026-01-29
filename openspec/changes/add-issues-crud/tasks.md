# Tasks

## 1. Routes
- [ ] 1.1 Add `/issues/new` route for issue creation
- [ ] 1.2 Add `/issues/:id` route for issue detail view
- [ ] 1.3 Add `/issues/:id/edit` route for issue editing (if using separate page)

## 2. Issue Detail View
- [ ] 2.1 Create `IssueLive.Show` module for detail view
- [ ] 2.2 Display all issue fields (title, description, status, type, priority, project, submitter, dates)
- [ ] 2.3 Add edit button for authorized users
- [ ] 2.4 Add delete button for authorized users
- [ ] 2.5 Handle 404 for non-existent or unauthorized issues

## 3. Issue Creation
- [ ] 3.1 Create `IssueLive.New` module with creation form
- [ ] 3.2 Create `IssueLive.FormComponent` for reusable form
- [ ] 3.3 Add project selection dropdown (account-scoped projects)
- [ ] 3.4 Implement form validation and error display
- [ ] 3.5 Redirect to issue detail on success
- [ ] 3.6 Add "New Issue" button to issues list header

## 4. Issue Editing
- [ ] 4.1 Add edit action to `IssueLive.Show` (modal or page)
- [ ] 4.2 Reuse `IssueLive.FormComponent` for edit form
- [ ] 4.3 Handle validation errors
- [ ] 4.4 Show success message on update

## 5. Issue Deletion
- [ ] 5.1 Add delete handler to `IssueLive.Show`
- [ ] 5.2 Show confirmation dialog before deletion
- [ ] 5.3 Redirect to issues list after deletion
- [ ] 5.4 Show success message

## 6. Testing
- [ ] 6.1 Add LiveView tests for show view
- [ ] 6.2 Add LiveView tests for create flow
- [ ] 6.3 Add LiveView tests for edit flow
- [ ] 6.4 Add LiveView tests for delete flow
- [ ] 6.5 Add tests for authorization (non-authorized users)
