# Change: Create Default Account on User Registration

## Why
New users currently have no account after registration, which means they cannot use account-scoped features (API keys, projects, etc.) without manually creating an account first. This creates unnecessary friction in the onboarding flow.

## What Changes
- Modify `register_user/1` to create a default "Personal" account for the user
- The user is assigned as the owner of this default account
- The operation is transactional (user + account created together or neither)

## Impact
- Affected specs: Creates new `user-registration` capability
- Affected code: `lib/app/accounts.ex` (register_user function)
- Tests: `test/app/accounts_test.exs`
