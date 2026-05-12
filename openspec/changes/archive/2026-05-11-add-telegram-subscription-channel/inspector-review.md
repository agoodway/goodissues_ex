# Inspector Review: add-telegram-subscription-channel

**Date**: 2026-05-11
**Verdict**: Ready

## Summary

Reviewed all change artifacts (proposal, design, tasks, 3 delta specs) against the codebase and the overlapping `add-subscriptions-api` change. The change is well-structured with strong spec-task coverage. Findings were primarily mechanical gaps and minor clarifications.

## Patches applied

7 findings were auto-patched. 3 findings were patched after user guidance. 0 findings were skipped.

### Auto-patched

1. **Task 2.2 partial index semantics** — `tasks.md:13` → Clarified to specify `WHERE bot_username IS NOT NULL` partial unique index
2. **Task 4.6 missing config path** — `tasks.md:37` → Added explicit `config/config.exs` target file
3. **Task 7.1 vague done condition** — `tasks.md:62` → Added explicit artifact sections to update and done condition
4. **Task 1.5 missing runtime.exs scope** — `tasks.md:7` → Expanded to include `config/runtime.exs`, `config/test.exs`, and `.env.sample`
5. **Missing NotificationLog channel task** — `tasks.md:25` → Added task 3.5 for updating `NotificationLog.changeset/2` channel validation at `notification_log.ex:56`
6. **Missing secret omission scenario** — `specs/subscriptions/spec.md` → Added "API omits secret for Telegram subscriptions" scenario
7. **Design Decision 8 missing module name** — `design.md` → Added `GoodIssuesWeb.AccountLive.Index` with action `:edit`
8. **Delivery logging spec gap** — `specs/telegram-notification-delivery/spec.md` → Added `telegram` as valid log channel to requirement text

### User-guided patches

1. **Unknown channel scenario misplaced** — `specs/telegram-notification-delivery/spec.md` → Removed "Unknown channel is not enqueued" scenario (user chose: remove, since it's generic listener behavior)
2. **Vault key validation qualifier** — `specs/account-telegram-settings/spec.md` → Removed "in an environment requiring encrypted fields" clause (user chose: always validate)
3. **Help text content unspecified** — `specs/subscriptions/spec.md` → Added content hints referencing `/start` and `getUpdates` (user chose: specify content)

### Skipped

None.

## Remaining findings

### Suggestions

1. **Proposal could note profile-delivery coupling** — `proposal.md` — The proposal says subscriptions support Telegram but doesn't note that delivery requires a configured Telegram profile (covered in delivery spec, but a cross-reference would help readers). Not patched because it's editorial.

## Confirmed non-issues

- **resolve_destination/1 handles Telegram**: `notifications.ex:58` — The `%EventSubscription{user_id: nil}` clause already matches Telegram subscriptions (which always have `user_id: nil`). No code change needed.
- **Cross-account chat ID duplicates**: Confirmed intentional — a Telegram group can receive notifications from multiple accounts.
- **Test endpoint response shape**: Uses the same `{ data: { status, channel, destination, error? } }` format as other channels, per `add-subscriptions-api`.
- **Show view Telegram details**: No extra detail rows for v1 — bot config lives in account settings.
- **GIVEN steps in scenarios**: Project convention uses WHEN/THEN without GIVEN (verified against `issues/spec.md`). Not a violation.

## Codebase alignment notes

The following codebase locations must be updated during implementation (all covered by existing tasks):

- `event_subscription.ex:33` — Add `"telegram"` to `@channels` (task 3.2)
- `notification_log.ex:56` — Add `"telegram"` to channel validation (task 3.5)
- `listener.ex:64-68` — Add `"telegram"` case to `enqueue_delivery/2` (task 4.7)
- `config/config.exs:85-94` — Add `notifications_telegram` queue (task 4.6)
- `application.ex` — Add `GI.Vault` to supervision tree (task 1.4)
- `mix.exs` — Add `cloak_ecto` dependency (task 1.1)
- `subscription_live/new.ex:161` — Add Telegram channel option (task 6.1)
- `subscription_live/new.ex:167-186` — Add Telegram destination input branch (task 6.2)
- `subscription_live/index.ex:58` — Add Telegram icon (task 6.4)
