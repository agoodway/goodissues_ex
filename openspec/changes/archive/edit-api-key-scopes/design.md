# Design: Edit API Key Scopes

## Context
API keys currently support scopes (an array of strings) as part of their schema. The scopes field is displayed on the show page but cannot be modified after creation. Users must revoke and recreate keys to change scopes, which is inconvenient and can cause disruption to applications using those keys.

### Current State
- API keys have a `scopes` field (array of strings)
- Scopes are set during key creation via the new key form
- Scopes are displayed on the show page as a comma-separated list
- No edit/update functionality exists for API keys

### User Request
Users accessing `/dashboard/admin-personal/api-keys/:id` want to be able to edit API key scopes directly from the dashboard interface.

## Goals / Non-Goals

### Goals
- Provide a UI for editing API key scopes
- Allow admins/owners to modify key permissions without recreating the key
- Maintain authorization checks (only owner/admin can edit keys in their account)
- Preserve all other API key attributes (name, type, token, status, expires_at) during update
- Provide form validation for scope format

### Non-Goals
- Editing other API key fields (name, type, expires_at, owner, status)
- Re-issuing or regenerating the API key token
- Editing revoked API keys
- Admin-wide API key editing (only account-scoped dashboard editing)

## Decisions

### 1. Scope Selection UI
**Decision**: Use checkboxes for scope selection. Display a list of available scopes as checkboxes, with an option for custom scopes.

**Alternatives considered**:
- Comma-separated text input: Simple but error-prone (typos, unclear what scopes are available)
- Multi-select dropdown: Complex UI, harder to use on mobile
- Tag input with autocomplete: Better UX but adds complexity

**Rationale**: Checkboxes provide a clear, user-friendly interface showing all available options. Users can see at a glance what scopes exist and simply check/uncheck them. This reduces errors and improves discoverability compared to free-form text input.

### 2. Authorization Model
**Decision**: Only account owners and admins can edit API keys within their account. Members have read-only access.

**Rationale**: Matches the existing pattern for API key management (creation, revocation). Scopes control access permissions, so they should be restricted to privileged roles.

### 3. Editable Fields
**Decision**: Only scopes are editable. Name, type, expires_at, and account_user are immutable after creation.

**Rationale**: The user request specifically mentions editing scopes. Other fields are critical identity and access characteristics that shouldn't change post-creation to maintain audit trails and prevent misuse.

### 3.1 Predefined vs Custom Scopes
**Decision**: Provide a predefined list of scopes via checkboxes, with no custom scope input.

**Rationale**: For MVP, checkboxes with predefined scopes provide a clean, error-resistant interface. Custom scope input can be added later if users need it. The checkboxes ensure users select from valid, supported scopes only.

### 4. Revoked Key Handling
**Decision**: Disallow editing revoked keys. Show an error message if user tries to edit a revoked key.

**Rationale**: Revoked keys are inactive and will be deleted. Editing them serves no purpose and could cause confusion.

### 5. LiveView Architecture
**Decision**: Create a new `ApiKeyLive.Edit` LiveView following the same patterns as `ApiKeyLive.New`.

**Rationale**: Maintains consistency with existing codebase patterns, follows Phoenix conventions for CRUD operations, and reuses existing form validation patterns.

## Risks / Trade-offs

### Risk: Scope Typos or Invalid Scopes
**Risk**: Users might enter invalid scope formats or non-existent scopes.

**Mitigation**:
- Provide clear placeholder and help text in the form
- Display current scopes in the form for reference
- Consider adding a "test scope" feature in future to validate scopes

### Risk: Permission Escalation
**Risk**: Admins could grant excessive permissions to existing keys.

**Mitigation**:
- Maintain audit logs of scope changes (future enhancement)
- Consider requiring confirmation for scope expansions
- Track last modified timestamp

### Trade-off: Single Field Edit
**Trade-off**: Only editing scopes feels limited compared to full key editing.

**Rationale**: Scopes are the most commonly modified attribute for access management. Other fields (name, type, owner) are rarely changed and have security implications. This scope keeps the change minimal and focused.

## Migration Plan

### Step 1: Add Context Function
- Add `update_api_key/2` to `FF.Accounts`
- Implement authorization checks
- Add unit tests

### Step 2: Create Edit LiveView
- Create `FFWeb.Dashboard.ApiKeyLive.Edit`
- Implement form with scopes field
- Add validation
- Handle success/error responses

### Step 3: Add Route
- Add edit route to router
- Ensure proper authentication/authorization

### Step 4: Update Show Page
- Add edit button/link to show page
- Only show for active keys and authorized users

### Step 5: Testing
- Write LiveView tests for edit page
- Test authorization (owner/admin vs member)
- Test revoked key handling
- Test form validation

### Step 6: Validation
- Run `mix precommit` to ensure code quality
- Manual testing in development environment

## Open Questions

1. **Predefined scope list**: What predefined scopes should be available as checkboxes?

   *Decision*: Define a list of scopes based on existing API endpoints and resources using `resource:action` format:
   - `projects:read` - Read access to projects
   - `projects:write` - Write access to projects
   - `issues:read` - Read access to issues
   - `issues:write` - Write access to issues
   - `errors:read` - Read access to errors
   - `errors:write` - Write access to errors
   - This list can be extended in the future as new resources are added.

2. **Scope format validation**: Should we validate that scopes match a specific pattern (e.g., `resource:action`) or allow any string?

   *Decision*: Only validate against the predefined checkbox list. Since checkboxes are used, users can only select from supported scopes. No custom scope input means no need for custom validation.

3. **Empty scopes handling**: Should empty scopes mean "all scopes" or "no scopes"?

   *Decision*: Empty array means "all scopes" (current behavior). When no checkboxes are selected, save an empty array (no restriction).

4. **Audit logging**: Should we log scope changes for security/compliance?

   *Decision*: Out of scope for this change. Can be added as a follow-up with an `api_key_scope_updates` audit table.

5. **Concurrent edits**: What happens if two admins edit the same key simultaneously?

   *Decision*: Use optimistic concurrency via Ecto changesets. The update will fail if the key was modified between load and save, displaying an error to the user.
