defmodule FF.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias FF.Repo

  alias FF.Accounts.{Account, AccountUser, ApiKey, User, UserToken, UserNotifier}

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.email_changeset(attrs)
    |> Repo.insert()
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `FF.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `FF.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  There are three cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email and no password is set.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The user has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end

  # ============================================
  # Account Functions
  # ============================================

  @doc "Get an account by ID"
  def get_account(id), do: Repo.get(Account, id)

  @doc "Get an account by ID with preloaded associations"
  def get_account!(id) do
    Account
    |> Repo.get!(id)
    |> Repo.preload(account_users: :user)
  end

  @doc "Get an account by slug"
  def get_account_by_slug(slug), do: Repo.get_by(Account, slug: slug)

  @doc "Create a new account with the given user as owner"
  def create_account(user, attrs) do
    Repo.transaction(fn ->
      with {:ok, account} <- %Account{} |> Account.changeset(attrs) |> Repo.insert(),
           {:ok, _account_user} <- add_user_to_account(account, user, :owner) do
        account
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc "List all accounts for a user"
  def list_user_accounts(user) do
    from(a in Account,
      join: au in AccountUser,
      on: au.account_id == a.id,
      where: au.user_id == ^user.id,
      select: {a, au.role}
    )
    |> Repo.all()
  end

  # ============================================
  # Admin Account Functions
  # ============================================

  @doc """
  Lists all accounts with optional filtering and pagination.

  ## Options

    * `:search` - Search term to filter by name or slug
    * `:status` - Filter by status (:active, :suspended)
    * `:page` - Page number (default: 1)
    * `:per_page` - Items per page (default: 20)

  """
  def list_accounts(opts \\ []) do
    search = Keyword.get(opts, :search)
    status = Keyword.get(opts, :status)
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)

    query =
      from(a in Account,
        order_by: [desc: a.inserted_at],
        preload: [account_users: :user]
      )

    query =
      if search && search != "" do
        search_term = "%#{search}%"
        from a in query, where: ilike(a.name, ^search_term) or ilike(a.slug, ^search_term)
      else
        query
      end

    query =
      if status && status != "" do
        status_atom = if is_binary(status), do: String.to_existing_atom(status), else: status
        from a in query, where: a.status == ^status_atom
      else
        query
      end

    total = Repo.aggregate(query, :count)

    accounts =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{
      accounts: accounts,
      total: total,
      page: page,
      per_page: per_page,
      total_pages: ceil(total / per_page)
    }
  end

  @doc "Returns an Account changeset for tracking changes"
  def change_account(%Account{} = account, attrs \\ %{}) do
    Account.changeset(account, attrs)
  end

  @doc "Creates an account (admin function, no owner assignment)"
  def admin_create_account(attrs) do
    %Account{}
    |> Account.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates an account"
  def update_account(%Account{} = account, attrs) do
    account
    |> Account.changeset(attrs)
    |> Repo.update()
  end

  @doc "Suspends an account"
  def suspend_account(%Account{} = account) do
    update_account(account, %{status: :suspended})
  end

  @doc "Activates a suspended account"
  def activate_account(%Account{} = account) do
    update_account(account, %{status: :active})
  end

  # ============================================
  # AccountUser (Membership) Functions
  # ============================================

  @doc "Get a user's membership in an account"
  def get_account_user(user, account) do
    Repo.get_by(AccountUser, user_id: user.id, account_id: account.id)
  end

  @doc "Get account_user by ID with preloads"
  def get_account_user!(id) do
    AccountUser
    |> Repo.get!(id)
    |> Repo.preload([:user, :account])
  end

  @doc "Add a user to an account with a role"
  def add_user_to_account(account, user, role \\ :member) do
    %AccountUser{}
    |> AccountUser.changeset(%{
      account_id: account.id,
      user_id: user.id,
      role: role
    })
    |> Repo.insert()
  end

  @doc "Remove a user from an account"
  def remove_user_from_account(account, user) do
    case get_account_user(user, account) do
      nil -> {:error, :not_found}
      account_user -> Repo.delete(account_user)
    end
  end

  @doc "Update a user's role in an account"
  def update_account_user_role(account_user, role) do
    account_user
    |> AccountUser.changeset(%{role: role})
    |> Repo.update()
  end

  # ============================================
  # API Key Functions
  # ============================================

  @doc "Verify an API token and return the key with account_user preloaded"
  def verify_api_token(token) do
    prefix = String.slice(token, 0, 12)
    hash = ApiKey.hash_token(token)

    query =
      from k in ApiKey,
        where: k.token_prefix == ^prefix and k.token_hash == ^hash,
        where: k.status == :active,
        where: is_nil(k.expires_at) or k.expires_at > ^DateTime.utc_now(),
        preload: [account_user: [:user, :account]]

    case Repo.one(query) do
      nil -> {:error, :invalid_token}
      api_key -> {:ok, api_key}
    end
  end

  @doc "Update last_used_at timestamp"
  def touch_api_key(api_key) do
    api_key
    |> Ecto.Changeset.change(last_used_at: DateTime.utc_now() |> DateTime.truncate(:second))
    |> Repo.update()
  end

  @doc "Create a new API key for an account_user (membership)"
  def create_api_key(account_user, attrs) do
    type = attrs[:type] || :public
    token = ApiKey.generate_token(type)
    prefix = String.slice(token, 0, 12)
    hash = ApiKey.hash_token(token)

    changeset =
      %ApiKey{account_user_id: account_user.id}
      |> ApiKey.changeset(Map.put(attrs, :account_user_id, account_user.id))
      |> Ecto.Changeset.put_change(:token_prefix, prefix)
      |> Ecto.Changeset.put_change(:token_hash, hash)

    case Repo.insert(changeset) do
      {:ok, api_key} -> {:ok, {api_key, token}}
      error -> error
    end
  end

  @doc "List API keys for an account_user"
  def list_api_keys(account_user) do
    from(k in ApiKey, where: k.account_user_id == ^account_user.id)
    |> Repo.all()
  end

  @doc "Revoke an API key"
  def revoke_api_key(api_key) do
    api_key
    |> Ecto.Changeset.change(status: :revoked)
    |> Repo.update()
  end
end
