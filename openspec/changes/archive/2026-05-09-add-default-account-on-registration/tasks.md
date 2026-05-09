## 1. Implementation
- [x] 1.1 Update `register_user/1` to wrap user creation in a transaction
- [x] 1.2 Create default "Personal" account after user is created
- [x] 1.3 Add user as owner of the default account via `AccountUser`

## 2. Testing
- [x] 2.1 Update existing `register_user/1` tests to verify account creation
- [x] 2.2 Add test for transaction rollback when account creation fails
- [x] 2.3 Verify user is owner of default account

## 3. Validation
- [x] 3.1 Run existing test suite to ensure no regressions
- [x] 3.2 Manual verification of registration flow
