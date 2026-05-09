# Design: Add Subscriptions API

## API Surface

```
GET    /api/v1/subscriptions          subscriptions:read
GET    /api/v1/subscriptions/:id      subscriptions:read
POST   /api/v1/subscriptions          subscriptions:write
PATCH  /api/v1/subscriptions/:id      subscriptions:write
DELETE /api/v1/subscriptions/:id      subscriptions:write
POST   /api/v1/subscriptions/:id/test subscriptions:write
```

## Request/Response Shapes

### Create Request

```json
{
  "name": "CI webhook",
  "channel": "webhook",
  "event_types": ["issue_created", "issue_status_changed"],
  "destination": "https://example.com/hooks/goodissues",
  "active": true
}
```

For email with user linking:

```json
{
  "name": "Notify dev lead",
  "channel": "email",
  "event_types": ["issue_created"],
  "user_id": "550e8400-..."
}
```

### Create Response (201)

```json
{
  "data": {
    "id": "...",
    "name": "CI webhook",
    "channel": "webhook",
    "event_types": ["issue_created", "issue_status_changed"],
    "destination": "https://example.com/hooks/goodissues",
    "criteria": null,
    "active": true,
    "user_id": null,
    "secret": "whsec_abc123...",
    "inserted_at": "2026-05-09T12:00:00Z",
    "updated_at": "2026-05-09T12:00:00Z"
  }
}
```

> `secret` is ONLY returned in the create response. All other responses omit it.

### Show/Index Response

Same shape as create but without `secret`.

### List Response (paginated)

```json
{
  "data": [ ... ],
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 3,
    "total_pages": 1
  }
}
```

### Update Request

Mutable fields only: `name`, `event_types`, `destination`, `user_id`, `criteria`, `active`.
Cannot change `channel` after creation.

### Test Response (200)

```json
{
  "data": {
    "status": "delivered",
    "channel": "webhook",
    "destination": "https://example.com/hooks/goodissues"
  }
}
```

On delivery failure:

```json
{
  "data": {
    "status": "failed",
    "channel": "webhook",
    "destination": "https://example.com/hooks/goodissues",
    "error": "Connection refused"
  }
}
```

## Architecture

```
┌──────────────┐     ┌────────────────────┐     ┌──────────────────┐
│  API Client  │────▶│ SubscriptionCtrl   │────▶│ GI.Notifications │
│              │     │                    │     │                  │
│              │     │ • OpenApiSpex ops  │     │ • CRUD (exists)  │
│              │     │ • Scope auth plugs │     │ • paginated (new)│
│              │     │ • Secret-once logic│     │ • emit (exists)  │
└──────────────┘     └────────────────────┘     └──────────────────┘
                              │
                     ┌────────┴────────┐
                     │ SubscriptionJSON│
                     │                 │
                     │ • data/1        │
                     │ • data_create/1 │ ← includes secret
                     └─────────────────┘
```

## Secret-Once Pattern

The JSON view has two render paths:

- **`data/1`** — standard serialization, omits `secret`
- **`data_with_secret/1`** — includes `secret`, used only in `create` response

The controller calls `render(conn, :create, subscription: sub)` vs `render(conn, :show, subscription: sub)` to trigger the right path.

## Test Endpoint

`POST /subscriptions/:id/test` creates a synthetic event:

```elixir
Event.new(:issue_created, account_id, %{
  test: true,
  subscription_id: subscription.id,
  message: "Test event from GoodIssues API"
})
```

This flows through the normal delivery pipeline (Listener → Workers). The controller waits briefly and returns delivery status. If the subscription is inactive, returns 422.

## Context Changes

Add `list_subscriptions_paginated/2` to `GI.Notifications`:

```elixir
def list_subscriptions_paginated(account_id, filters \\ %{}) do
  {page, per_page} = extract_pagination(filters)
  # ... same pattern as Tracking.list_issues_paginated
end
```

Uses the same `extract_pagination` helper pattern from `GI.Tracking`.
