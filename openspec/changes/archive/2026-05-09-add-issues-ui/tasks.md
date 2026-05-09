# Tasks

## 1. Backend Preparation
- [x] 1.1 Add `list_issues_paginated/2` function to Tracking context (returns paginated results with total count)
- [x] 1.2 Preload project association in list query

## 2. Routes & Navigation
- [x] 2.1 Add `/dashboard/:account_slug/issues` route to router
- [x] 2.2 Update sidebar navigation in `layouts.ex` to link to issues

## 3. Issue List View
- [x] 3.1 Create `IssueLive.Index` module with list view
- [x] 3.2 Implement pagination
- [x] 3.3 Display issue attributes (status, title, type, priority, project, date)
- [x] 3.4 Match industrial terminal aesthetic from API Keys UI
- [x] 3.5 Add empty state display

## 4. Testing
- [x] 4.1 Add LiveView tests for index view
- [x] 4.2 Add tests for pagination
- [x] 4.3 Add tests for empty state
