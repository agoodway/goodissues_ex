# Spec: Subscriptions API

## Capability

REST API endpoints for managing event subscriptions (webhooks, email, and Telegram notifications).

## Requirements

### CRUD Endpoints

- **LIST** `GET /api/v1/subscriptions`
  - Returns paginated subscriptions for the authenticated account
  - Supports `page` and `per_page` query params
  - Response wraps data in `{ data: [...], meta: { page, per_page, total, total_pages } }`
  - Requires `subscriptions:read` scope

- **SHOW** `GET /api/v1/subscriptions/:id`
  - Returns a single subscription by ID
  - Scoped to authenticated account (cannot access other accounts' subscriptions)
  - Never returns `secret`
  - Requires `subscriptions:read` scope

- **CREATE** `POST /api/v1/subscriptions`
  - Accepts: `name`, `channel`, `event_types`, `destination`, `user_id`, `criteria`, `active`
  - `channel` must be `"email"`, `"webhook"`, or `"telegram"`
  - `event_types` must contain at least one valid event type
  - Webhook: requires `destination` (https URL), must not have `user_id`, auto-generates `secret`
  - Email: requires either `destination` (email address) or `user_id` (not both)
  - Telegram: requires `destination` (numeric chat ID matching `^-?\d+$`), must not have `user_id`, no `secret` generated
  - Returns 201 with the subscription including `secret` (webhook only, shown once)
  - Requires `subscriptions:write` scope

- **UPDATE** `PATCH /api/v1/subscriptions/:id`
  - Accepts: `name`, `event_types`, `destination`, `user_id`, `criteria`, `active`
  - Cannot change `channel` after creation
  - Returns 200 with updated subscription (no `secret`)
  - Requires `subscriptions:write` scope

- **DELETE** `DELETE /api/v1/subscriptions/:id`
  - Returns 204 No Content on success
  - Requires `subscriptions:write` scope

### Test Endpoint

- **TEST** `POST /api/v1/subscriptions/:id/test`
  - Sends a synthetic test event through the delivery pipeline
  - Returns `{ data: { status, channel, destination, error? } }`
  - Returns 422 if subscription is inactive
  - Requires `subscriptions:write` scope

### Authentication & Authorization

- All endpoints require Bearer token auth (API key)
- Read endpoints use `subscriptions:read` scope
- Write endpoints use `subscriptions:write` scope
- All queries scoped to the API key's account

### Validation

- Inherits all validation from `EventSubscription.changeset/2`:
  - Channel must be "email", "webhook", or "telegram"
  - At least one valid event type required
  - Webhook destination must be https (http://localhost allowed in dev/test)
  - Cannot set both `destination` and `user_id`
  - Webhook must have `destination`, must not have `user_id`
  - Telegram must have `destination` (numeric chat ID), must not have `user_id`
- Returns 422 with changeset errors on validation failure
- Returns 404 for IDs not found within the account

### Valid Event Types

- `issue_created`
- `issue_updated`
- `issue_status_changed`
- `error_occurred`
- `error_resolved`
