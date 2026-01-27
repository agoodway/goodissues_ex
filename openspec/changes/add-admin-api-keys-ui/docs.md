# API Key Management Documentation

## Access Requirements

### Who Can Access

API key management is available through the account dashboard at `/dashboard/:account_slug/api-keys`. Access requirements:

1. **Authentication**: User must be logged in
2. **Account Membership**: User must be a member of the account they're accessing
3. **Role-Based Permissions**:
   - **View API Keys**: All account members (owner, admin, member)
   - **Create API Keys**: Owner and admin roles only
   - **Revoke API Keys**: Owner and admin roles only

Members with read-only access will see an informational message indicating they should contact an admin for management actions.

### Route Protection

Routes are protected by the `load_account_from_slug` on_mount hook which:
- Verifies the user is authenticated
- Loads the account from the URL slug
- Verifies the user has membership in that account
- Sets the `current_scope` with account and role information

## API Key Lifecycle Management

### Creating an API Key

1. Navigate to Dashboard > API Keys > New API Key
2. Fill in the required fields:
   - **Name**: A descriptive name for the key (required)
   - **Type**: Public (read-only) or Private (read/write)
   - **Scopes**: Optional comma-separated list of scopes (e.g., `read:projects, write:projects`)
   - **Expires At**: Optional expiration date
3. Click "Create API Key"
4. **Critical**: Copy the displayed token immediately (see Token Security below)

### Viewing API Keys

The API Keys index page displays all keys for the current account with:
- Name, Type, Owner (email), Status, Last Used, Expires dates
- Filtering by status (Active/Revoked) and type (Public/Private)
- Search by name or owner email
- Pagination (20 keys per page)

Click "View" on any key to see full details including:
- Token prefix (first characters only)
- Complete owner and account information
- Full activity timestamps (created, updated, last used, expires)

### Revoking an API Key

1. Navigate to the API key's detail page or find it in the list
2. Click "Revoke" (only visible for active keys to owners/admins)
3. Confirm the action in the confirmation dialog
4. The key status changes to "revoked" and can no longer authenticate requests

**Note**: Revocation is permanent and cannot be undone. If access is needed again, create a new API key.

## Token Security Considerations

### Display Once Policy

The full API token is **only displayed once** at the moment of creation. This is a critical security measure:

- The token is shown on the creation confirmation page
- A prominent warning alerts users to save the token immediately
- A "Copy" button is provided for clipboard copying
- After navigating away, only the token prefix is ever displayed

### Why Tokens Cannot Be Retrieved

- Tokens are hashed before storage using secure one-way hashing
- Only the prefix (first 12 characters) is stored in plaintext for identification
- This protects tokens even if the database is compromised

### Best Practices

1. **Copy immediately**: Use the copy button to save the token as soon as it's created
2. **Store securely**: Save tokens in a password manager or secure vault
3. **Never share tokens**: Treat API tokens like passwords
4. **Use appropriate type**: Use public (read-only) keys when write access isn't needed
5. **Set expiration**: For temporary access, set an expiration date
6. **Revoke unused keys**: Regularly audit and revoke keys that are no longer needed
7. **Monitor usage**: Check the "Last Used" timestamp to identify inactive keys

### Key Types

- **Public Keys** (`pk_...`): Read-only access to API endpoints
- **Private Keys** (`sk_...`): Full read/write access to API endpoints

## Dashboard Navigation

### Accessing API Keys

1. Log in to the application
2. Navigate to `/dashboard` (redirects to your first account)
3. Or navigate directly to `/dashboard/:account_slug`
4. Click "API Keys" in the dashboard sidebar

### Dashboard Layout

The API Keys section is part of the account-scoped dashboard which includes:
- Account overview/settings
- API Keys management

The dashboard header shows the current account name and the user's role within that account.

### Switching Accounts

If you have access to multiple accounts:
1. Use the account switcher in the dashboard
2. Or navigate directly to `/dashboard/:other_account_slug/api-keys`
