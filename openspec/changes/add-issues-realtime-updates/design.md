## Context
FruitFly's issues list view is a Phoenix LiveView that displays paginated issues. Users can create/update issues via both the admin dashboard and the REST API. Currently, when an issue is created or updated via the API, the dashboard doesn't reflect these changes until a manual page refresh.

The application already has Phoenix PubSub configured (`{Phoenix.PubSub, name: FF.PubSub}` in `application.ex`), and the endpoint has `pubsub_server: FF.PubSub` set in config. This provides the infrastructure for lightweight pub/sub messaging.

**Stakeholders**: Dashboard users who need to see realtime updates when issues are created or modified.

## Goals / Non-Goals
- **Goals**:
  - Broadcast issue creation/update events to connected dashboard users
  - Automatically update the issues list when new issues are created via API
  - Maintain existing pagination and filter behavior with realtime updates
  - Keep implementation minimal and straightforward

- **Non-Goals**:
  - Realtime collaborative editing of issue details
  - Realtime issue deletion notifications (can be added later)
  - Presence features (showing which users are viewing issues)
  - WebSocket fallback or offline support

## Decisions

### 1. Use Phoenix PubSub (not Phoenix Presence)
**Decision**: Broadcast issue events using Phoenix PubSub's `broadcast/3` function.

**Rationale**: PubSub is already configured and provides lightweight, asynchronous message broadcasting without the overhead of Presence tracking. We don't need to know which users are connected, just need to push updates to anyone listening.

**Alternatives considered**:
- **Phoenix Presence**: More complex, includes user tracking overhead that we don't need
- **Direct LiveView events**: Limited to a single LiveView process, doesn't work across multiple browser tabs

### 2. Channel Topic Per-Account
**Decision**: Use topic pattern `"issues:account:<account_id>"` for scoping events.

**Rationale**: Multi-tenant architecture requires scoping. Users should only receive updates for issues within their account. Using account_id in the topic ensures proper isolation and security.

**Topic naming**: `FF.PubSub.subscribe(FF.PubSub, "issues:account:#{account_id}")`

### 3. Event Payload Format
**Decision**: Use standardized event types and payloads.

```elixir
# Issue created
{:issue_created, %{
  id: issue.id,
  project_id: issue.project_id,
  title: issue.title,
  status: issue.status,
  type: issue.type,
  priority: issue.priority,
  number: issue.number,
  inserted_at: issue.inserted_at,
  project: %{
    id: issue.project.id,
    prefix: issue.project.prefix
  }
}}

# Issue updated
{:issue_updated, %{
  id: issue.id,
  title: issue.title,
  status: issue.status,
  type: issue.type,
  priority: issue.priority,
  updated_at: issue.updated_at
}}
```

**Rationale**: Includes only fields needed for list display and filtering. Preloading project relationship avoids N+1 queries when rebroadcasting.

### 4. LiveView Integration Strategy
**Decision**: Handle PubSub messages via `handle_info/2` in `IssueLive.Index`.

**Rationale**: Phoenix PubSub delivers messages as Elixir process messages to the LiveView process. Using `handle_info/2` is the standard pattern for handling PubSub subscriptions in LiveViews.

```elixir
def handle_info({:issue_created, issue_data}, socket) do
  # Add to current page or update count
  {:noreply, socket}
end

def handle_info({:issue_updated, issue_data}, socket) do
  # Update or remove from list if status changed
  {:noreply, socket}
end
```

### 5. Pagination Handling
**Decision**: When an issue is created via API, increment the total count and notify users; don't auto-add to current page to avoid breaking pagination logic.

**Rationale**: Auto-adding to current page could:
- Break pagination (showing 21 items instead of 20)
- Cause duplicate items if issue doesn't match current filters
- Create confusing UX if issue appears in wrong order

**Better approach**: Show a toast notification like "1 new issue created" with a link to navigate to the first page to see it.

## Risks / Trade-offs

### Risk 1: Memory Pressure with Many Subscriptions
**Mitigation**: PubSub subscriptions are per-process. With LiveView, only users actively viewing the issues page maintain subscriptions. Users with 10+ open tabs would have 10+ subscriptions, but this is acceptable given the lightweight nature of PubSub.

### Risk 2: Race Conditions (Issue Created vs Filter Applied)
**Mitigation**: If an issue is created but doesn't match current filters, simply update the total count. The `handle_info` checks current filter state before deciding to add the issue.

### Risk 3: Missing Updates During LiveView Disconnect
**Mitigation**: Standard Phoenix behavior. When LiveView reconnects, it re-fetches data, so missing updates are naturally recovered. No special handling needed.

### Trade-off: Channel vs Direct PubSub
We chose PubSub directly over creating a Phoenix Channel because:
- LiveView can subscribe to PubSub topics directly
- No WebSocket upgrade overhead required for admin users (LiveView already uses WebSocket)
- Simpler implementation (no channel module needed)

However, this means API consumers can't subscribe to issue events without implementing their own WebSocket/HTTP polling. Future enhancement could add a proper Phoenix Channel for API integration.

## Migration Plan

### Phase 1: Add PubSub Broadcasting
1. Update `Tracking.create_issue/3` to broadcast `:issue_created` event on success
2. Update `Tracking.update_issue/2` to broadcast `:issue_updated` event on success
3. Add tests for broadcasting behavior

### Phase 2: LiveView Subscription & Handling
1. Update `IssueLive.Index.mount/3` to subscribe to account's issue topic
2. Add `handle_info/2` for `:issue_created` and `:issue_updated`
3. Implement logic to update assigns based on current filters and pagination
4. Add toast notification for new issues
5. Add tests for realtime update handling

### Phase 3: Cleanup & Documentation
1. Update documentation to note realtime behavior
2. Add comments explaining topic naming and payload structure
3. Run `mix precommit` to ensure all tests pass

### Rollback
If issues arise, can disable broadcasting by commenting out `FF.PubSub.broadcast` calls without breaking existing functionality. The change is additive and non-breaking.

## Open Questions

1. **Should we broadcast issue deletion events?**
   - **Answer**: Not in this change. Can be added later if needed. Deletion is less frequent and users can detect it via refresh.

2. **Should we show a visual indicator when new issues are created?**
   - **Answer**: Yes, use a toast notification "1 new issue created" with a link to navigate to first page.

3. **How do we handle issue status changes that move issues off the current filter?**
   - **Answer**: Remove the issue from the list using `Enum.reject` and decrement the displayed count.

4. **Should we broadcast to all dashboard users or only admin users?**
   - **Answer**: All users viewing the issues list, regardless of role. The issue data broadcast already respects account scoping via the topic name.
