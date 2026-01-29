# Tasks

## 1. Search
- [ ] 1.1 Add search input to issues list header
- [ ] 1.2 Implement `handle_event` for search with debounce
- [ ] 1.3 Add title search to `Tracking.list_issues/2` filters

## 2. Filter Controls
- [ ] 2.1 Add status filter dropdown to issues list header
- [ ] 2.2 Add type filter dropdown to issues list header
- [ ] 2.3 Add priority filter dropdown to issues list header
- [ ] 2.4 Add project filter dropdown to issues list header

## 3. Filter Logic
- [ ] 3.1 Add `handle_event` handlers for each filter type
- [ ] 3.2 Update URL query params when search/filters change
- [ ] 3.3 Parse search and filter params in `handle_params`
- [ ] 3.4 Pass filters to `Tracking.list_issues/2`

## 4. UI Polish
- [ ] 4.1 Style search input with terminal aesthetic ($ grep -i ...)
- [ ] 4.2 Style filters to match terminal aesthetic (--status=*, --type=*, etc.)
- [ ] 4.3 Show active filter state in dropdowns
- [ ] 4.4 Reset pagination to page 1 when search/filters change

## 5. Testing
- [ ] 5.1 Add tests for search functionality
- [ ] 5.2 Add tests for status filtering
- [ ] 5.3 Add tests for type filtering
- [ ] 5.4 Add tests for priority filtering
- [ ] 5.5 Add tests for project filtering
- [ ] 5.6 Add tests for combined search and filters
