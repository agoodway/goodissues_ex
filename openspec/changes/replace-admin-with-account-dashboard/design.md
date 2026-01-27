# Design: Replace Admin with Account Dashboard

## Architecture Overview

This change transforms the authentication and authorization model from a global admin flag to an account-scoped permission system.

```
Before:
┌──────────┐     is_admin=true      ┌──────────────┐
│   User   │ ─────────────────────> │ /admin/*     │
└──────────┘                        │ (all accts)  │
                                    └──────────────┘

After:
┌──────────┐     AccountUser        ┌──────────────┐
│   User   │ ───────────────────┬─> │ Account A    │
└──────────┘     (role: owner)  │   └──────────────┘
                                │
                    (role: member)
                                │   ┌──────────────┐
                                └─> │ Account B    │
                                    └──────────────┘

                    │
                    v
            ┌──────────────┐
            │ /dashboard/* │  (scoped to selected account)
            └──────────────┘
```

## Scope Modifications

### Current Scope Structure
```elixir
defstruct user: nil
```

### New Scope Structure
```elixir
defstruct user: nil,
          account: nil,           # Currently selected account
          account_user: nil,      # Membership with role info
          accounts: []            # All user's accounts (for switcher)
```

### Permission Helpers
```elixir
def can_manage_account?(%Scope{account_user: %{role: role}})
    when role in [:owner, :admin], do: true
def can_manage_account?(_), do: false

def can_view_account?(%Scope{account_user: %AccountUser{}}), do: true
def can_view_account?(_), do: false
```

## Session/State Management

### Account Selection Flow
1. User logs in
2. On dashboard access, check session for `selected_account_id`
3. If present and valid (user is member), use it
4. Otherwise, select first account alphabetically
5. Store selection in session

### Session Keys
- `selected_account_id` - UUID of currently selected account

### LiveView State
```elixir
# In mount or handle_params
socket
|> assign(:current_account, account)
|> assign(:account_user, account_user)
|> assign(:user_accounts, user_accounts)  # For switcher dropdown
```

## Route Structure

### Before
```
/admin/accounts          # List ALL accounts
/admin/accounts/:id      # Show/edit ANY account
/admin/api-keys          # List ALL API keys
/admin/api-keys/:id      # Show ANY API key
```

### After
```
/dashboard                        # Dashboard home (with account switcher)
/dashboard/account                # Current account settings
/dashboard/api-keys               # API keys for current account membership
/dashboard/api-keys/:id           # Show specific API key
/dashboard/members                # Account members (owner/admin only)
```

## Authorization Strategy

### Route-Level Authorization
```elixir
# In router.ex
live_session :dashboard,
  on_mount: [
    {FFWeb.UserAuth, :ensure_authenticated},
    {FFWeb.UserAuth, :ensure_account_selected}  # New
  ] do
  # Routes here
end
```

### Action-Level Authorization
For actions requiring `owner`/`admin` role:
```elixir
# In LiveView
def handle_event("update_account", params, socket) do
  if Scope.can_manage_account?(socket.assigns.current_scope) do
    # Proceed
  else
    {:noreply, put_flash(socket, :error, "Permission denied")}
  end
end
```

### Component-Level Authorization
```heex
<.button :if={Scope.can_manage_account?(@current_scope)} phx-click="edit">
  Edit Account
</.button>
```

## Account Switcher Component

### Location
Persistent in dashboard layout header/sidebar

### Behavior
- Dropdown showing all user's accounts
- Current account highlighted
- On selection: POST to `/dashboard/switch-account` or LiveView event
- Updates session and reloads dashboard

### Implementation Options

**Option A: Full page reload (simpler)**
```elixir
# In router
post "/dashboard/switch-account", DashboardController, :switch_account
```

**Option B: LiveView navigation (smoother)**
```elixir
def handle_event("switch_account", %{"account_id" => id}, socket) do
  # Validate membership, update session, push_navigate
end
```

Recommendation: **Option A** for simplicity - account switching is infrequent.

## File/Module Rename Plan

```
# Directories
lib/app_web/live/admin/         → lib/app_web/live/dashboard/
lib/app_web/live/admin/account_live/   → lib/app_web/live/dashboard/account_live/
lib/app_web/live/admin/api_key_live/   → lib/app_web/live/dashboard/api_key_live/

# Modules
FFWeb.Admin.AccountLive.Index   → FFWeb.Dashboard.AccountLive.Index
FFWeb.Admin.AccountLive.Show    → FFWeb.Dashboard.AccountLive.Show
FFWeb.Admin.ApiKeyLive.*        → FFWeb.Dashboard.ApiKeyLive.*

# Plugs
FFWeb.Plugs.AdminAuth           → DELETE (replaced by Scope checks)

# Components
FFWeb.Layouts.admin/1           → FFWeb.Layouts.dashboard/1
```

## Data Migration Considerations

### Pre-Migration Verification
```elixir
# Query to find admins without account memberships
from u in User,
  where: u.is_admin == true,
  left_join: au in AccountUser, on: au.user_id == u.id,
  where: is_nil(au.id) or au.role not in [:owner, :admin],
  select: u
```

### Migration Script
```elixir
def up do
  # 1. Ensure all is_admin users have account memberships
  execute """
    INSERT INTO account_users (id, user_id, account_id, role, inserted_at, updated_at)
    SELECT gen_random_uuid(), u.id, a.id, 'owner', NOW(), NOW()
    FROM users u
    CROSS JOIN (SELECT id FROM accounts ORDER BY inserted_at LIMIT 1) a
    WHERE u.is_admin = true
    AND NOT EXISTS (
      SELECT 1 FROM account_users au
      WHERE au.user_id = u.id AND au.role IN ('owner', 'admin')
    )
  """

  # 2. Remove is_admin column
  alter table(:users) do
    remove :is_admin
  end
end
```

## Testing Strategy

### Unit Tests
- `Scope` permission helpers
- Account selection logic

### Integration Tests
- Dashboard access with various roles
- Account switching
- Permission-gated actions

### Test Fixture Updates
- Remove `admin_user_fixture` helper
- Add `account_with_owner_fixture`
- Update `conn_case.ex` helpers
