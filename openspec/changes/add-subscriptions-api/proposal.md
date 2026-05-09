# Add Subscriptions API

## Summary

Expose event subscription CRUD via the REST API at `/api/v1/subscriptions`. The context layer (`GI.Notifications`) already has full CRUD — this change adds the controller, JSON view, OpenApiSpex schemas, router entries, and a test endpoint for webhook verification.

## Motivation

Subscriptions currently exist only in the dashboard UI. API consumers need to programmatically register webhooks and email subscriptions to integrate GoodIssues events into their workflows — CI pipelines, Slack bots, monitoring dashboards, etc.

## Scope

### In scope

- `GET /api/v1/subscriptions` — paginated list
- `GET /api/v1/subscriptions/:id` — show single subscription
- `POST /api/v1/subscriptions` — create (returns `secret` once for webhooks)
- `PATCH /api/v1/subscriptions/:id` — update
- `DELETE /api/v1/subscriptions/:id` — delete
- `POST /api/v1/subscriptions/:id/test` — send a test event to verify delivery
- OpenApiSpex schemas for all request/response bodies
- Auth scopes: `subscriptions:read`, `subscriptions:write`
- Paginated `list_subscriptions_paginated/2` context function

### Out of scope

- Notification logs API (separate change)
- New event types
- Webhook retry configuration
- Secret rotation endpoint

## Design Decisions

1. **Secret shown once**: The webhook signing secret (`whsec_...`) is returned in the create response only. Show/index responses omit it. Callers must store it at creation time.

2. **`user_id` exposed**: The API accepts `user_id` for email subscriptions that resolve the recipient dynamically. The user must belong to the same account.

3. **Paginated list**: Follows the same pattern as Issues (`page`, `per_page` query params, `meta` envelope).

4. **Test endpoint**: `POST /subscriptions/:id/test` emits a synthetic event through the existing delivery pipeline. Returns success/failure of the delivery attempt.

## Affected Areas

- `lib/good_issues_web/controllers/api/v1/` — new controller, JSON view, schemas
- `lib/good_issues_web/router.ex` — new route entries
- `lib/good_issues/notifications.ex` — add `list_subscriptions_paginated/2`
- `app/openapi.json` — regenerated spec
- `test/good_issues_web/controllers/api/v1/` — controller tests
