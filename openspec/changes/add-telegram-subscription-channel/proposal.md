## Why

Teams need an instant notification channel for issue and error events that is faster than email and cheaper/simpler than webhook integrations. Telegram subscriptions let each account connect its own bot and receive richly formatted GoodIssues event notifications in real time.

## What Changes

- Add Telegram as a first-class subscription channel alongside email and webhook.
- Store per-account Telegram bot configuration in a `telegram_profiles` table with the bot token encrypted at rest using Cloak.
- Add `cloak_ecto` support, a GoodIssues vault, and an encrypted binary Ecto type for sensitive integration fields.
- Add a Telegram delivery worker that sends MarkdownV2 messages through the Telegram Bot API using Req.
- Add Telegram-specific message formatting for existing issue and error event types.
- Update dashboard subscription management to allow static Telegram chat ID destinations.
- Update the subscriptions REST API proposal and OpenAPI schemas to include Telegram in the channel enum and validation contract.
- Keep v1 destinations static only: Telegram subscriptions require `destination` to be a Telegram chat ID and do not support `user_id` linked destinations.

## Capabilities

### New Capabilities

- `account-telegram-settings`: Per-account Telegram bot token and optional bot username management with encrypted token storage.
- `telegram-notification-delivery`: Telegram Bot API client, MarkdownV2 formatting, delivery worker, delivery logging, and queue configuration.

### Modified Capabilities

- `subscriptions`: Subscription creation, update, listing, dashboard UI, and REST API behavior include Telegram as a valid static-destination channel.

## Impact

- **Database**: Add `telegram_profiles`, update `event_subscriptions` channel check constraint, and store encrypted bot token bytes.
- **Dependencies**: Add `cloak_ecto` for encrypted fields; continue using existing Req and Oban dependencies.
- **Configuration**: Add `GI.Vault` to supervision and require a `CLOAK_KEY` for environments that use encrypted fields.
- **Delivery pipeline**: Add Telegram worker, Telegram client behavior/HTTP implementation, Telegram message formatter, and `notifications_telegram` Oban queue.
- **Dashboard**: Add account Telegram settings UI and extend subscription forms/list/detail views for Telegram.
- **API/OpenAPI**: Expand subscriptions API channel enum and validation docs from `email | webhook` to `email | webhook | telegram`.
- **Tests**: Add schema/context tests for Telegram profiles, worker/client/formatter tests, dashboard tests, API contract tests, and encryption/vault smoke tests.
