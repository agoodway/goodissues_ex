# Tasks: Add Subscriptions API

## 1. Add paginated list to context

- [ ] Add `list_subscriptions_paginated/2` to `GI.Notifications`
- [ ] Follow `Tracking.list_issues_paginated` pattern (page/per_page/total/total_pages)
- [ ] Support channel filter param

## 2. Create OpenApiSpex schemas

- [ ] Create `lib/good_issues_web/controllers/api/v1/schemas/subscription.ex`
  - [ ] `SubscriptionChannel` enum schema (email, webhook)
  - [ ] `EventType` enum schema
  - [ ] `SubscriptionRequest` (create body)
  - [ ] `SubscriptionUpdateRequest` (update body)
  - [ ] `SubscriptionSchema` (response shape, no secret)
  - [ ] `SubscriptionCreateSchema` (response shape, with secret)
  - [ ] `SubscriptionResponse` (data wrapper)
  - [ ] `SubscriptionCreateResponse` (data wrapper with secret)
  - [ ] `SubscriptionListResponse` (paginated wrapper)
  - [ ] `SubscriptionTestResponse`

## 3. Create JSON view

- [ ] Create `lib/good_issues_web/controllers/api/v1/subscription_json.ex`
  - [ ] `index/1` — paginated list render
  - [ ] `show/1` — single subscription (no secret)
  - [ ] `create/1` — single subscription (with secret)
  - [ ] `test_result/1` — test delivery result

## 4. Create controller

- [ ] Create `lib/good_issues_web/controllers/api/v1/subscription_controller.ex`
  - [ ] `use OpenApiSpex.ControllerSpecs`
  - [ ] `tags(["Subscriptions"])`
  - [ ] Scope plugs: `subscriptions:read` for index/show, `subscriptions:write` for create/update/delete/test
  - [ ] `action_fallback GIWeb.FallbackController`
  - [ ] `index/2` — list with pagination
  - [ ] `show/2` — get by ID
  - [ ] `create/2` — create and render with secret
  - [ ] `update/2` — update and render without secret
  - [ ] `delete/2` — delete and return 204
  - [ ] `test/2` — emit test event and return delivery status

## 5. Add routes

- [ ] Add read routes to `:api_authenticated` scope
  - [ ] `GET /subscriptions`
  - [ ] `GET /subscriptions/:id`
- [ ] Add write routes to `:api_write` scope
  - [ ] `POST /subscriptions`
  - [ ] `PATCH /subscriptions/:id`
  - [ ] `DELETE /subscriptions/:id`
  - [ ] `POST /subscriptions/:id/test`

## 6. Write tests

- [ ] Create `test/good_issues_web/controllers/api/v1/subscription_controller_test.exs`
  - [ ] Test index returns paginated subscriptions
  - [ ] Test show returns subscription without secret
  - [ ] Test create returns subscription with secret
  - [ ] Test create webhook validates https destination
  - [ ] Test create validates event_types
  - [ ] Test create validates channel
  - [ ] Test update cannot change channel
  - [ ] Test update returns subscription without secret
  - [ ] Test delete returns 204
  - [ ] Test test endpoint with active subscription
  - [ ] Test test endpoint with inactive subscription returns 422
  - [ ] Test account scoping (cannot access other accounts)
  - [ ] Test scope authorization (read vs write)

## 7. Regenerate OpenAPI spec

- [ ] Run `mix openapi.spec.json` to update `openapi.json`
