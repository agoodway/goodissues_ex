## Context

GoodIssues already has an event notification pipeline with `GI.Notifications.emit/1`, a global `GI.Notifications.Listener`, `EventSubscription` records, email delivery, webhook delivery, Oban queues, delivery logs, and dashboard subscription management. The active `add-subscriptions-api` change exposes the existing subscription model over REST and currently scopes the API contract to email and webhook channels.

GoodLeads has a completed `telegram-subscription-channel` change that proves the target pattern: account-owned Telegram bot configuration, Cloak-encrypted bot tokens, a Telegram client behavior, a Telegram Oban worker, MarkdownV2 message formatting, and channel-specific subscription validation. GoodIssues should adopt the same architectural shape while keeping the v1 destination model simpler: static Telegram chat IDs only, no user-linked Telegram destinations.

GoodIssues does not currently include Cloak or any encrypted Ecto field type. Adding per-account bot tokens therefore introduces a small security foundation that should be reusable for future sensitive integration settings.

## Goals / Non-Goals

**Goals:**

- Add Telegram as a first-class subscription channel for issue and error events.
- Let each account configure its own Telegram bot token and optional bot username.
- Encrypt Telegram bot tokens at rest with Cloak-backed Ecto fields.
- Deliver Telegram notifications through Oban using the existing listener and delivery-log pattern.
- Use Telegram MarkdownV2 formatting from v1 instead of reusing email/plain text bodies.
- Include Telegram in the dashboard subscription UI and in the subscriptions REST API contract.
- Keep Telegram subscription destinations static by requiring a Telegram chat ID in `destination`.

**Non-Goals:**

- No user-linked Telegram subscriptions in v1; `user_id` remains invalid for Telegram subscriptions.
- No `users.telegram_chat_id` field in v1.
- No Telegram webhook endpoint, `/start` flow, automatic chat ID discovery, or bot command handling.
- No inline keyboards, buttons, reply handling, group/channel management, or interactive Telegram features.
- No bot token validation against Telegram on save; failed delivery is surfaced through delivery logs.
- No notification template authoring for Telegram in v1.

## Decisions

### 1. Store Telegram bot config in `telegram_profiles`

Create a `GI.TelegramProfiles.TelegramProfile` schema backed by a `telegram_profiles` table with a unique `account_id`, encrypted `bot_token_encrypted`, optional `bot_username`, and timestamps. Add `has_one :telegram_profile` to `GI.Accounts.Account`.

This follows the proven GoodLeads account-integration pattern and keeps sensitive integration fields out of the already-central `accounts` table. `bot_username` is optional because delivery only needs the token; the username is useful for display and operator clarity but should not block setup.

Alternative considered: store the token in runtime config as a single app-wide bot. That would be simpler but would not satisfy the requirement that each account can use its own bot.

### 2. Add Cloak as the encrypted-field foundation

Add `:cloak_ecto`, a `GI.Vault` module, and `GI.Encrypted.Binary`. The vault uses AES-GCM with a 32-byte key decoded from `CLOAK_KEY`, matching the GoodLeads approach.

`GI.Vault` must be supervised before code loads encrypted fields from the database. Runtime config should require `CLOAK_KEY` in environments that need encrypted field access. Tests can use a deterministic key in test config or test environment setup.

Alternative considered: store bot tokens as plain strings like webhook secrets. This is unacceptable for account-owned third-party credentials because bot tokens grant send access to an external Telegram bot.

### 3. Telegram subscriptions use static `destination` only

Telegram subscriptions require `channel: "telegram"`, a static `destination` containing a Telegram chat ID, and no `user_id`. Chat IDs must match Telegram's integer ID shape, including negative values for groups/supergroups: `^-?\d+$`.

This keeps v1 consistent with the user's chosen scope and avoids adding profile fields or delivery-time user resolution. Email remains the only linked-user destination in the existing model.

Alternative considered: add `users.telegram_chat_id` and resolve linked users. That is useful later, but it expands the user settings surface and introduces UX around finding and maintaining personal chat IDs.

### 4. Telegram delivery mirrors existing workers

Add `GI.Notifications.Workers.TelegramWorker` using queue `:notifications_telegram`, max attempts 5, and uniqueness on `[:event_id, :destination]` for 60 seconds. The listener dispatches `"telegram"` subscriptions to this worker.

The worker flow is:

1. Validate `destination` as a Telegram chat ID.
2. Load the account's Telegram profile.
3. Cancel without retry if no Telegram profile/token exists.
4. Build a MarkdownV2 message for the event.
5. Send via the configured Telegram client.
6. Write a `NotificationLog` with channel `telegram` and status `delivered` or `failed`.

This preserves the current delivery pipeline and makes Telegram operationally similar to email/webhook.

### 5. Telegram client is a behavior plus Req implementation

Add `GI.Notifications.TelegramClient` with `send_message/3`, and `GI.Notifications.TelegramClient.HTTP` that sends `POST https://api.telegram.org/bot<token>/sendMessage` with JSON body containing `chat_id`, `text`, `parse_mode: "MarkdownV2"`, and `disable_web_page_preview: true`.

The implementation should be configurable via `Application.get_env(:good_issues, :telegram_client, GI.Notifications.TelegramClient.HTTP)` so tests can use a mock or test module without real network calls.

### 6. Telegram gets dedicated MarkdownV2 formatting

Add `GI.Notifications.TelegramMessages` with `build/2` and `escape_markdown/1`. The formatter should cover all current GoodIssues event types: `issue_created`, `issue_updated`, `issue_status_changed`, `error_occurred`, and `error_resolved`, with a safe fallback for unknown event types.

Dynamic values must escape Telegram MarkdownV2 control characters. Message content should be concise but richer than email text, with a GoodIssues header and event-specific fields where available.

### 7. Include Telegram in dashboard and API subscription contracts

Update `EventSubscription` channel validation and the database channel constraint to include `telegram`. Update dashboard subscription create/show/list behavior to render Telegram labels, icons, static chat ID fields, and help text for finding a chat ID.

Update the active subscriptions API artifacts and implementation so API clients can create, list, update, delete, and test Telegram subscriptions. The API must document and enforce Telegram-specific validation: `destination` required, `user_id` forbidden, chat ID format required, and `secret` absent.

### 8. Telegram settings live in account settings v1

Add Telegram profile management to the existing account-scoped settings surface (`GoodIssuesWeb.AccountLive.Index` with action `:edit` at `/dashboard/:account_slug/settings`) instead of introducing a new settings route. GoodIssues currently has a compact account settings page, so a Telegram settings section keeps navigation simple for v1 and avoids creating a new settings tab system just for one integration.

Alternative considered: add a dedicated `/dashboard/:account_slug/settings/telegram` route like GoodLeads. That is useful if GoodIssues grows multiple account integration settings, but it is more UI structure than this change needs.

## Risks / Trade-offs

- **Invalid or revoked bot token causes delivery failures** -> Do not validate on save; fail gracefully in `TelegramWorker`, record delivery logs, and allow admins to update the profile.
- **CLOAK_KEY misconfiguration breaks encrypted field access** -> Validate key presence/length at startup and document generation with `32 |> :crypto.strong_rand_bytes() |> Base.encode64()`.
- **MarkdownV2 escaping bugs can break sends** -> Centralize escaping in `TelegramMessages.escape_markdown/1` and test dynamic fields containing all Telegram control characters.
- **Telegram rate limits can delay bursts** -> Use an Oban queue with modest concurrency; rely on retries for transient rate-limit errors.
- **Active `add-subscriptions-api` drift** -> Update that change's specs/design/tasks during implementation so its enum, examples, and tests include `telegram` rather than shipping email/webhook-only docs.

## Migration Plan

1. Add Cloak dependency, vault, encrypted type, and supervision entry.
2. Add `telegram_profiles` and channel-constraint migrations.
3. Deploy with `CLOAK_KEY` configured before using Telegram settings.
4. Add Telegram profile management and subscription validation.
5. Add worker/client/formatter and queue configuration.
6. Expand dashboard and API surfaces.

Rollback requires disabling Telegram subscription creation, removing or ignoring `telegram` subscriptions, and preserving `telegram_profiles` data until no encrypted fields need to be read. The channel constraint cannot be rolled back to email/webhook-only while any Telegram subscriptions exist.

## Open Questions

- None.
