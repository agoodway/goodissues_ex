# Change: Add Account Audit Trail

## Why
The admin accounts UI references audit logging in several scenarios (create, update, deactivate, role changes) but the actual audit trail infrastructure and display was deferred. Admins need visibility into account changes for compliance and troubleshooting.

## What Changes
- Add audit trail logging infrastructure to record account-related events
- Add UI to display account activity/audit trail on the account detail page
- Implement audit log queries with filtering and pagination

## Impact
- Affected specs: admin-accounts
- Affected code: Account context, Admin.AccountLive.Show
