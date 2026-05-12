## 1. Cloak Encryption Foundation

- [x] 1.1 Add `:cloak_ecto` dependency to `app/mix.exs` and update lockfile
- [x] 1.2 Create `GI.Vault` using AES-GCM and a 32-byte Base64-decoded `CLOAK_KEY`
- [x] 1.3 Create `GI.Encrypted.Binary` Ecto type backed by `GI.Vault`
- [x] 1.4 Add `GI.Vault` to the supervision tree before encrypted fields are loaded
- [x] 1.5 Add `CLOAK_KEY` configuration: read from env in `config/runtime.exs`, validate key length, add a deterministic test key in `config/test.exs`, and update `.env.sample`
- [x] 1.6 Add vault smoke tests for encrypt/decrypt and invalid key behavior where practical

## 2. Telegram Profile Data Model

- [x] 2.1 Generate migration for `telegram_profiles` with `account_id`, `bot_token_encrypted`, optional `bot_username`, and timestamps
- [x] 2.2 Add unique index on `telegram_profiles.account_id` and a partial unique index on `bot_username` WHERE `bot_username IS NOT NULL`
- [x] 2.3 Create `GI.TelegramProfiles.TelegramProfile` schema with encrypted token field and redacted virtual `bot_token`
- [x] 2.4 Add changeset validation for required account, required token on create, optional username normalization, token masking, and constraints
- [x] 2.5 Add `has_one :telegram_profile` to `GI.Accounts.Account`
- [x] 2.6 Create `GI.TelegramProfiles` context with get/change/create/update/delete functions scoped by account
- [x] 2.7 Add schema and context tests for create, update, delete, optional username, uniqueness, and encrypted token persistence

## 3. Subscription Channel Validation

- [x] 3.1 Generate migration to update `event_subscriptions_channel_check` to include `telegram`
- [x] 3.2 Add `telegram` to `GI.Notifications.EventSubscription` channel validation
- [x] 3.3 Add Telegram-specific validation requiring static `destination` and forbidding `user_id`
- [x] 3.4 Add Telegram chat ID validation using `^-?\d+$`
- [x] 3.5 Add `telegram` to `NotificationLog.changeset/2` channel validation (`validate_inclusion(:channel, ~w(email webhook telegram))` in `notification_log.ex:56`)
- [x] 3.6 Ensure webhook secret generation remains webhook-only and Telegram responses never include a secret
- [x] 3.7 Add EventSubscription tests for valid Telegram chat IDs, invalid chat IDs, missing destination, and rejected `user_id`

## 4. Telegram Delivery Pipeline

- [x] 4.1 Create `GI.Notifications.TelegramClient` behavior with `send_message/3`
- [x] 4.2 Create `GI.Notifications.TelegramClient.HTTP` using Req and Telegram `sendMessage` with MarkdownV2
- [x] 4.3 Add `:telegram_client` application config for test substitution
- [x] 4.4 Create `GI.Notifications.TelegramMessages` with MarkdownV2 escaping and event-specific builders
- [x] 4.5 Create `GI.Notifications.Workers.TelegramWorker` with queue `notifications_telegram`, max attempts, uniqueness, account profile lookup, delivery logging, and graceful cancellation paths
- [x] 4.6 Add `notifications_telegram` queue to Oban configuration in `config/config.exs`
- [x] 4.7 Update `GI.Notifications.Listener` to dispatch `telegram` subscriptions to `TelegramWorker`
- [x] 4.8 Add tests for Telegram client success/failure responses
- [x] 4.9 Add tests for MarkdownV2 escaping and all current GoodIssues event type messages
- [x] 4.10 Add worker tests for success, missing profile, invalid chat ID, Telegram API failure, and delivery log creation
- [x] 4.11 Add listener tests confirming Telegram jobs enqueue for matching subscriptions

## 5. Account Telegram Settings UI

- [x] 5.1 Add Telegram profile form state to the existing account settings LiveView/page
- [x] 5.2 Render Telegram bot token and optional bot username fields in account settings
- [x] 5.3 Support creating a Telegram profile from account settings for account managers
- [x] 5.4 Support updating Telegram token and optional username while preserving masked unchanged token values
- [x] 5.5 Support deleting/removing Telegram profile configuration with confirmation
- [x] 5.6 Hide or disable Telegram profile mutation controls for users without account-management permission
- [x] 5.7 Add LiveView/dashboard tests for create, update, delete, optional username, masked token preservation, and unauthorized access

## 6. Dashboard Subscription UI

- [x] 6.1 Add Telegram to subscription channel options in the new subscription form
- [x] 6.2 Render Telegram-specific destination label and chat ID help text when channel is `telegram`
- [x] 6.3 Ensure Telegram subscription submissions pass static chat ID destination params and no `user_id`
- [x] 6.4 Add Telegram channel icon/badge rendering to subscription list and detail views
- [x] 6.5 Add dashboard tests for creating, listing, viewing, toggling, and deleting Telegram subscriptions

## 7. Subscriptions API Integration

- [x] 7.1 Update `add-subscriptions-api` artifacts to include Telegram: add `telegram` to the channel enum in `specs/subscriptions/spec.md`, update proposal scope to mention Telegram, and update any design sections referencing channel lists. Done when the `add-subscriptions-api` spec validates `email | webhook | telegram`
- [x] 7.2 Add Telegram to OpenApiSpex subscription channel enum and request/response schema descriptions (N/A: subscriptions API not yet implemented; EventSubscription schema already validates telegram; OpenApiSpex schemas will include telegram when add-subscriptions-api is built)
- [x] 7.3 Ensure API create accepts Telegram subscriptions with valid static chat ID destinations (N/A: covered by EventSubscription.changeset validation)
- [x] 7.4 Ensure API update applies Telegram validation and still prevents channel changes (N/A: covered by EventSubscription.update_changeset validation)
- [x] 7.5 Ensure API show/index serialize Telegram subscriptions without webhook secrets (N/A: clear_secret_for_telegram/1 ensures secret is nil)
- [x] 7.6 Ensure API test endpoint sends Telegram test events through the normal delivery pipeline (N/A: API not yet implemented)
- [x] 7.7 Add API tests for Telegram create, validation errors, list/show serialization, update, delete, test endpoint, account scoping, and scopes (N/A: API not yet implemented; schema validation tested in event_subscription_telegram_test.exs)

## 8. Documentation, OpenAPI, and Verification

- [x] 8.1 Regenerate `app/openapi.json` after API schema updates (N/A: no subscription schemas in openapi.json yet)
- [x] 8.2 Add or update `.env.sample`/runtime documentation for `CLOAK_KEY` generation
- [x] 8.3 Run focused tests for Telegram profiles, subscriptions, delivery workers, dashboard UI, and API controller behavior
- [x] 8.4 Run `mix format` in `app/`
- [x] 8.5 Run `mix precommit` in `app/` and resolve failures (771 tests pass; 1 pre-existing failure in page_controller_test.exs unrelated to this change)
