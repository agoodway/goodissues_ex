defmodule GI.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `GI.Accounts.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  ## Fields

    * `:user` - The current user
    * `:account` - The currently selected account (for dashboard/account-scoped views)
    * `:account_user` - The user's membership in the current account
    * `:accounts` - List of all accounts the user belongs to (with roles)

  """

  alias GI.Accounts.{AccountUser, User}

  defstruct user: nil, account: nil, account_user: nil, accounts: []

  @type t :: %__MODULE__{
          user: User.t() | nil,
          account: GI.Accounts.Account.t() | nil,
          account_user: AccountUser.t() | nil,
          accounts: [{GI.Accounts.Account.t(), atom()}]
        }

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil

  @doc """
  Creates a scope with a selected account.

  The account_user represents the user's membership in the account,
  and accounts is the list of all accounts the user belongs to.
  """
  def with_account(%__MODULE__{} = scope, account, account_user, accounts) do
    %{scope | account: account, account_user: account_user, accounts: accounts}
  end

  @doc """
  Checks if the scope has a selected account.
  """
  def has_account?(%__MODULE__{account: nil}), do: false
  def has_account?(%__MODULE__{account: _account}), do: true
  def has_account?(_), do: false

  @doc """
  Checks if the user can view the current account (any membership).
  """
  def can_view_account?(%__MODULE__{account_user: nil}), do: false
  def can_view_account?(%__MODULE__{account_user: %AccountUser{}}), do: true
  def can_view_account?(_), do: false

  @doc """
  Checks if the user can manage the current account (owner or admin role).
  """
  def can_manage_account?(%__MODULE__{account_user: nil}), do: false

  def can_manage_account?(%__MODULE__{account_user: %AccountUser{role: role}})
      when role in [:owner, :admin],
      do: true

  def can_manage_account?(_), do: false

  @doc """
  Checks if the user is the owner of the current account.
  """
  def owner?(%__MODULE__{account_user: %AccountUser{role: :owner}}), do: true
  def owner?(_), do: false
end
