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
    Repo.transact(fn ->
      with {:ok, user} <- %User{} |> User.email_changeset(attrs) |> Repo.insert(),
           {:ok, _account} <- create_default_account(user) do
        {:ok, user}
      end
    end)
  end

  defp create_default_account(user) do
    # Generate unique slug from user email prefix
    slug = user.email |> String.split("@") |> hd() |> generate_unique_slug()

    with {:ok, account} <-
           %Account{} |> Account.changeset(%{name: "Personal", slug: slug}) |> Repo.insert(),
         {:ok, _account_user} <- add_user_to_account(account, user, :owner) do
      {:ok, account}
    end
  end

  defp generate_unique_slug(base, attempt \\ 0) do
    slug =
      base
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "-")
      |> String.trim("-")
      |> then(&"#{&1}-personal#{suffix(attempt)}")

    if Repo.exists?(from(a in Account, where: a.slug == ^slug)) do
      generate_unique_slug(base, attempt + 1)
    else
      slug
    end
  end

  defp suffix(0), do: ""
  defp suffix(n), do: "-#{n}"

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

  @doc """
  Loads account context for a user by slug in a single query.

  Returns `{:ok, account, account_user, all_user_accounts}` if the user is a member
  of the account, or `{:error, :not_found}` if account doesn't exist, or
  `{:error, :not_member}` if user is not a member.
  """
  def load_account_context_by_slug(user, slug) do
    # Single query to get account and user's membership
    account_query =
      from(a in Account,
        left_join: au in AccountUser,
        on: au.account_id == a.id and au.user_id == ^user.id,
        where: a.slug == ^slug,
        select: {a, au}
      )

    case Repo.one(account_query) do
      nil ->
        {:error, :not_found}

      {_account, nil} ->
        {:error, :not_member}

      {account, account_user} ->
        # Get all user accounts (this is needed for the account switcher)
        accounts = get_user_accounts(user)
        {:ok, account, account_user, accounts}
    end
  end

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
      case parse_account_status(status) do
        nil -> query
        status_atom -> from a in query, where: a.status == ^status_atom
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

  @doc """
  Fetches all accounts a user belongs to with their membership details.

  Returns a list of tuples `{account, role}` sorted by account name.
  """
  def get_user_accounts(user) do
    from(au in AccountUser,
      where: au.user_id == ^user.id,
      join: a in assoc(au, :account),
      order_by: [asc: a.name],
      preload: [:account],
      select: au
    )
    |> Repo.all()
    |> Enum.map(fn au -> {au.account, au.role} end)
  end

  @doc """
  Fetches a user's membership for a specific account by account ID.

  Returns the AccountUser with preloaded account, or nil if not a member.
  """
  def get_account_user_by_id(user, account_id) do
    from(au in AccountUser,
      where: au.user_id == ^user.id and au.account_id == ^account_id,
      preload: [:account]
    )
    |> Repo.one()
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

  @doc """
  Atomically revokes an API key, verifying account membership and role in a single operation.

  Returns `{:ok, api_key}` on success, or `{:error, reason}` on failure where reason
  can be `:not_found`, `:not_authorized`, or a changeset.
  """
  def revoke_account_api_key(%Account{} = account, %AccountUser{} = actor, api_key_id) do
    Repo.transact(fn ->
      # Re-verify actor's current role in the account
      actor_query =
        from(au in AccountUser,
          where: au.id == ^actor.id and au.account_id == ^account.id,
          where: au.role in [:owner, :admin],
          lock: "FOR UPDATE"
        )

      unless Repo.exists?(actor_query) do
        throw({:error, :not_authorized})
      end

      # Get and lock the API key, verifying it belongs to this account
      api_key_query =
        from(k in ApiKey,
          join: au in AccountUser,
          on: k.account_user_id == au.id,
          where: k.id == ^api_key_id and au.account_id == ^account.id,
          where: k.status == :active,
          lock: "FOR UPDATE",
          select: k
        )

      case Repo.one(api_key_query) do
        nil ->
          throw({:error, :not_found})

        api_key ->
          api_key
          |> Ecto.Changeset.change(status: :revoked)
          |> Repo.update()
      end
    end)
  catch
    {:error, reason} -> {:error, reason}
  end

  @doc "Get an API key by ID with preloaded associations"
  def get_api_key!(id) do
    ApiKey
    |> Repo.get!(id)
    |> Repo.preload(account_user: [:user, :account])
  end

  @doc "Returns an ApiKey changeset for tracking changes"
  def change_api_key(%ApiKey{} = api_key, attrs \\ %{}) do
    ApiKey.changeset(api_key, attrs)
  end

  @doc """
  Lists all API keys with optional filtering and pagination.

  ## Options

    * `:search` - Search term to filter by name or owner email
    * `:status` - Filter by status (:active, :revoked)
    * `:type` - Filter by type (:public, :private)
    * `:page` - Page number (default: 1)
    * `:per_page` - Items per page (default: 20)

  """
  def list_all_api_keys(opts \\ []) do
    search = Keyword.get(opts, :search)
    status = Keyword.get(opts, :status)
    type = Keyword.get(opts, :type)
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)

    query =
      from(k in ApiKey,
        join: au in assoc(k, :account_user),
        join: u in assoc(au, :user),
        join: a in assoc(au, :account),
        order_by: [desc: k.inserted_at],
        preload: [account_user: {au, user: u, account: a}]
      )

    query =
      if search && search != "" do
        search_term = "%#{search}%"

        from [k, au, u, a] in query,
          where: ilike(k.name, ^search_term) or ilike(u.email, ^search_term)
      else
        query
      end

    query =
      case parse_api_key_status(status) do
        nil -> query
        status_atom -> from k in query, where: k.status == ^status_atom
      end

    query =
      case parse_api_key_type(type) do
        nil -> query
        type_atom -> from k in query, where: k.type == ^type_atom
      end

    total = Repo.aggregate(query, :count)

    api_keys =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{
      api_keys: api_keys,
      total: total,
      page: page,
      per_page: per_page,
      total_pages: ceil(total / per_page)
    }
  end

  @doc "List all account_users for API key creation dropdown"
  def list_all_account_users do
    from(au in AccountUser,
      join: u in assoc(au, :user),
      join: a in assoc(au, :account),
      order_by: [asc: u.email, asc: a.name],
      preload: [user: u, account: a]
    )
    |> Repo.all()
  end

  @doc """
  Lists API keys for a specific account with pagination and filtering.

  Returns a map with api_keys, total, page, per_page, and total_pages.

  ## Options

    * `:search` - Search term to filter by key name or owner email
    * `:status` - Filter by status (:active or :revoked)
    * `:type` - Filter by type (:public or :private)
    * `:page` - Page number (default: 1)
    * `:per_page` - Items per page (default: 20)
  """
  def list_account_api_keys(%Account{} = account, opts \\ []) do
    search = Keyword.get(opts, :search)
    status = Keyword.get(opts, :status)
    type = Keyword.get(opts, :type)
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)

    query =
      from(k in ApiKey,
        join: au in assoc(k, :account_user),
        join: u in assoc(au, :user),
        join: a in assoc(au, :account),
        where: a.id == ^account.id,
        order_by: [desc: k.inserted_at],
        preload: [account_user: {au, user: u, account: a}]
      )

    query =
      if search && search != "" do
        search_term = "%#{search}%"

        from [k, au, u, _a] in query,
          where: ilike(k.name, ^search_term) or ilike(u.email, ^search_term)
      else
        query
      end

    query =
      case parse_api_key_status(status) do
        nil -> query
        status_atom -> from k in query, where: k.status == ^status_atom
      end

    query =
      case parse_api_key_type(type) do
        nil -> query
        type_atom -> from k in query, where: k.type == ^type_atom
      end

    total = Repo.aggregate(query, :count)

    api_keys =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{
      api_keys: api_keys,
      total: total,
      page: page,
      per_page: per_page,
      total_pages: ceil(total / per_page)
    }
  end

  @doc """
  Gets an API key by ID, but only if it belongs to the given account.

  Returns nil if not found or doesn't belong to the account.
  """
  def get_account_api_key(%Account{} = account, id) do
    from(k in ApiKey,
      join: au in assoc(k, :account_user),
      join: u in assoc(au, :user),
      join: a in assoc(au, :account),
      where: k.id == ^id and a.id == ^account.id,
      preload: [account_user: {au, user: u, account: a}]
    )
    |> Repo.one()
  end

  @doc """
  Gets an API key by ID, but only if it belongs to the given account.

  Raises `Ecto.NoResultsError` if not found.
  """
  def get_account_api_key!(%Account{} = account, id) do
    case get_account_api_key(account, id) do
      nil -> raise Ecto.NoResultsError, queryable: ApiKey
      api_key -> api_key
    end
  end

  # ============================================
  # Safe Atom Parsing Helpers
  # ============================================

  defp parse_account_status("active"), do: :active
  defp parse_account_status("suspended"), do: :suspended
  defp parse_account_status(status) when is_atom(status), do: status
  defp parse_account_status(_), do: nil

  defp parse_api_key_status("active"), do: :active
  defp parse_api_key_status("revoked"), do: :revoked
  defp parse_api_key_status(status) when is_atom(status), do: status
  defp parse_api_key_status(_), do: nil

  defp parse_api_key_type("public"), do: :public
  defp parse_api_key_type("private"), do: :private
  defp parse_api_key_type(type) when is_atom(type), do: type
  defp parse_api_key_type(_), do: nil
end
