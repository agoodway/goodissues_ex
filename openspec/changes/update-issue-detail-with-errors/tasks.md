# Tasks

## Phase 1: Context Layer

- [ ] Add `get_error_summary/1` helper to get error with occurrence count
- [ ] Update `get_issue/3` to support preloading error with occurrence count
- [ ] Write context tests for error preloading

## Phase 2: LiveView Updates

- [ ] Update `IssueLive.Show` mount to preload error data
- [ ] Add error summary section to show.ex render
- [ ] Add collapsible stacktrace component for latest occurrence
- [ ] Add mute toggle event handler
- [ ] Add status toggle event handler
- [ ] Style error section consistent with existing terminal-card design

## Phase 3: Testing

- [ ] Write LiveView tests for error display (with error, without error)
- [ ] Write LiveView tests for mute toggle
- [ ] Write LiveView tests for status toggle
- [ ] Test permission checks (can_manage required for controls)
