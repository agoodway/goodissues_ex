# Tasks

## Phase 1: Context Layer

- [x] Add `get_error_summary/1` helper to get error with occurrence count
- [x] Update `get_issue/3` to support preloading error with occurrence count
- [x] Write context tests for error preloading

## Phase 2: LiveView Updates

- [x] Update `IssueLive.Show` mount to preload error data
- [x] Add error summary section to show.ex render
- [x] Add collapsible stacktrace component for latest occurrence
- [x] Add mute toggle event handler
- [x] Add status toggle event handler
- [x] Style error section consistent with existing terminal-card design

## Phase 3: Testing

- [x] Write LiveView tests for error display (with error, without error)
- [x] Write LiveView tests for mute toggle
- [x] Write LiveView tests for status toggle
- [x] Test permission checks (can_manage required for controls)
