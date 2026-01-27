defmodule FF.AccountsTest do
  use FF.DataCase

  alias FF.Accounts

  import FF.AccountsFixtures
  alias FF.Accounts.{Scope, User, UserToken}

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture() |> set_password()
      refute Accounts.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture() |> set_password()

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!("11111111-1111-1111-1111-111111111111")
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "register_user/1" do
    test "requires email to be set" do
      {:error, changeset} = Accounts.register_user(%{})

      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email when given" do
      {:error, changeset} = Accounts.register_user(%{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum values for email for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_user(%{email: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness" do
      %{email: email} = user_fixture()
      {:error, changeset} = Accounts.register_user(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the uppercased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_user(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers users without password" do
      email = unique_user_email()
      {:ok, user} = Accounts.register_user(valid_user_attributes(email: email))
      assert user.email == email
      assert is_nil(user.hashed_password)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end

    test "creates default Personal account for new user" do
      email = unique_user_email()
      {:ok, user} = Accounts.register_user(valid_user_attributes(email: email))

      accounts = Accounts.get_user_accounts(user)
      assert length(accounts) == 1

      {account, role} = hd(accounts)
      assert account.name == "Personal"
      assert role == :owner
    end

    test "generates unique slug when collision exists" do
      email = "testuser123@example.com"
      slug = "testuser123-personal"

      # Create an account with the expected slug first
      {:ok, _existing} = Accounts.admin_create_account(%{name: "Personal", slug: slug})

      # Now try to register - should succeed with a suffixed slug
      {:ok, user} = Accounts.register_user(valid_user_attributes(email: email))

      # Verify the user was created
      assert user.id
      assert Accounts.get_user_by_email(email)

      # Verify the account was created with a unique suffixed slug
      [{account, :owner}] = Accounts.get_user_accounts(user)
      assert account.slug == "testuser123-personal-1"
    end
  end

  describe "sudo_mode?/2" do
    test "validates the authenticated_at time" do
      now = DateTime.utc_now()

      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.utc_now()})
      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -19, :minute)})
      refute Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -21, :minute)})

      # minute override
      refute Accounts.sudo_mode?(
               %User{authenticated_at: DateTime.add(now, -11, :minute)},
               -10
             )

      # not authenticated
      refute Accounts.sudo_mode?(%User{})
    end
  end

  describe "change_user_email/3" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_email(%User{})
      assert changeset.required == [:email]
    end
  end

  describe "deliver_user_update_email_instructions/3" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "change:current@example.com"
    end
  end

  describe "update_user_email/2" do
    setup do
      user = unconfirmed_user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{user: user, token: token, email: email}
    end

    test "updates the email with a valid token", %{user: user, token: token, email: email} do
      assert {:ok, %{email: ^email}} = Accounts.update_user_email(user, token)
      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == email
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email with invalid token", %{user: user} do
      assert Accounts.update_user_email(user, "oops") ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      assert Accounts.update_user_email(%{user | email: "current@example.com"}, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      assert Accounts.update_user_email(user, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "change_user_password/3" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_user_password(
          %User{},
          %{
            "password" => "new valid password"
          },
          hash_password: false
        )

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_user_password(user, %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{user: user} do
      {:ok, {user, expired_tokens}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      assert expired_tokens == []
      assert is_nil(user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)

      {:ok, {_, _}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"
      assert user_token.authenticated_at != nil

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end

    test "duplicates the authenticated_at of given user in new token", %{user: user} do
      user = %{user | authenticated_at: DateTime.add(DateTime.utc_now(:second), -3600)}
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.authenticated_at == user.authenticated_at
      assert DateTime.compare(user_token.inserted_at, user.authenticated_at) == :gt
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert {session_user, token_inserted_at} = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
      assert session_user.authenticated_at != nil
      assert token_inserted_at != nil
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      dt = ~N[2020-01-01 00:00:00]
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: dt, authenticated_at: dt])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "get_user_by_magic_link_token/1" do
    setup do
      user = user_fixture()
      {encoded_token, _hashed_token} = generate_user_magic_link_token(user)
      %{user: user, token: encoded_token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Accounts.get_user_by_magic_link_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_magic_link_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_magic_link_token(token)
    end
  end

  describe "login_user_by_magic_link/1" do
    test "confirms user and expires tokens" do
      user = unconfirmed_user_fixture()
      refute user.confirmed_at
      {encoded_token, hashed_token} = generate_user_magic_link_token(user)

      assert {:ok, {user, [%{token: ^hashed_token}]}} =
               Accounts.login_user_by_magic_link(encoded_token)

      assert user.confirmed_at
    end

    test "returns user and (deleted) token for confirmed user" do
      user = user_fixture()
      assert user.confirmed_at
      {encoded_token, _hashed_token} = generate_user_magic_link_token(user)
      assert {:ok, {^user, []}} = Accounts.login_user_by_magic_link(encoded_token)
      # one time use only
      assert {:error, :not_found} = Accounts.login_user_by_magic_link(encoded_token)
    end

    test "raises when unconfirmed user has password set" do
      user = unconfirmed_user_fixture()
      {1, nil} = Repo.update_all(User, set: [hashed_password: "hashed"])
      {encoded_token, _hashed_token} = generate_user_magic_link_token(user)

      assert_raise RuntimeError, ~r/magic link log in is not allowed/, fn ->
        Accounts.login_user_by_magic_link(encoded_token)
      end
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "deliver_login_instructions/2" do
    setup do
      %{user: unconfirmed_user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "login"
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end

  describe "list_accounts/1" do
    test "returns all accounts with pagination" do
      user = user_fixture()
      # user_fixture creates 1 default "Personal" account, so we add 24 more for 25 total
      for i <- 1..24 do
        account_fixture(user, %{name: "Account #{i}"})
      end

      result = Accounts.list_accounts()

      assert length(result.accounts) == 20
      assert result.total == 25
      assert result.page == 1
      assert result.total_pages == 2
    end

    test "filters by search term" do
      user = user_fixture()
      account_fixture(user, %{name: "Findable Account"})
      account_fixture(user, %{name: "Other Account"})

      result = Accounts.list_accounts(search: "Findable")

      assert length(result.accounts) == 1
      assert hd(result.accounts).name == "Findable Account"
    end

    test "filters by status" do
      user = user_fixture()
      # user_fixture creates 1 default "Personal" account (active)
      _active_account = account_fixture(user, %{name: "Active"})
      suspended_account = account_fixture(user, %{name: "Suspended"})
      Accounts.suspend_account(suspended_account)

      result = Accounts.list_accounts(status: :suspended)

      assert length(result.accounts) == 1
      assert hd(result.accounts).name == "Suspended"

      result = Accounts.list_accounts(status: :active)
      # 2 active accounts: the default "Personal" account + the "Active" account
      assert length(result.accounts) == 2
    end
  end

  describe "admin_create_account/1" do
    test "creates account without owner" do
      {:ok, account} = Accounts.admin_create_account(%{name: "Admin Created"})

      assert account.name == "Admin Created"
      assert account.slug == "admin-created"
      assert account.status == :active
    end

    test "returns error changeset with invalid data" do
      {:error, changeset} = Accounts.admin_create_account(%{name: nil})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_account/2" do
    test "updates account with valid data" do
      user = user_fixture()
      account = account_fixture(user)

      {:ok, updated} = Accounts.update_account(account, %{name: "Updated Name"})

      assert updated.name == "Updated Name"
    end
  end

  describe "suspend_account/1" do
    test "suspends an active account" do
      user = user_fixture()
      account = account_fixture(user)
      assert account.status == :active

      {:ok, suspended} = Accounts.suspend_account(account)

      assert suspended.status == :suspended
    end
  end

  describe "activate_account/1" do
    test "activates a suspended account" do
      user = user_fixture()
      account = account_fixture(user)
      {:ok, suspended} = Accounts.suspend_account(account)
      assert suspended.status == :suspended

      {:ok, activated} = Accounts.activate_account(suspended)

      assert activated.status == :active
    end
  end

  describe "get_api_key!/1" do
    test "returns API key with preloaded associations" do
      user = user_fixture()
      account = account_fixture(user)
      {_token, api_key} = api_key_fixture(user, account)

      fetched = Accounts.get_api_key!(api_key.id)

      assert fetched.id == api_key.id
      assert fetched.account_user.user.email == user.email
      assert fetched.account_user.account.name == account.name
    end

    test "raises if API key does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_api_key!("11111111-1111-1111-1111-111111111111")
      end
    end
  end

  describe "list_all_api_keys/1" do
    test "returns all API keys with pagination" do
      user = user_fixture()
      account = account_fixture(user)
      account_user = Accounts.get_account_user(user, account)

      for i <- 1..25 do
        Accounts.create_api_key(account_user, %{name: "Key #{i}", type: :public})
      end

      result = Accounts.list_all_api_keys()

      assert length(result.api_keys) == 20
      assert result.total == 25
      assert result.page == 1
      assert result.total_pages == 2
    end

    test "filters by search term (name)" do
      user = user_fixture()
      account = account_fixture(user)
      account_user = Accounts.get_account_user(user, account)

      {:ok, {findable, _}} =
        Accounts.create_api_key(account_user, %{name: "Findable Key", type: :public})

      {:ok, {_other, _}} =
        Accounts.create_api_key(account_user, %{name: "Other Key", type: :public})

      result = Accounts.list_all_api_keys(search: "Findable")

      assert length(result.api_keys) == 1
      assert hd(result.api_keys).name == findable.name
    end

    test "filters by status" do
      user = user_fixture()
      account = account_fixture(user)
      account_user = Accounts.get_account_user(user, account)

      {:ok, {active_key, _}} =
        Accounts.create_api_key(account_user, %{name: "Active Key", type: :public})

      {:ok, {revoked_key, _}} =
        Accounts.create_api_key(account_user, %{name: "Revoked Key", type: :public})

      Accounts.revoke_api_key(revoked_key)

      result = Accounts.list_all_api_keys(status: :revoked)

      assert length(result.api_keys) == 1
      assert hd(result.api_keys).name == "Revoked Key"

      result = Accounts.list_all_api_keys(status: :active)
      assert length(result.api_keys) == 1
      assert hd(result.api_keys).name == active_key.name
    end

    test "filters by type" do
      user = user_fixture()
      account = account_fixture(user)
      account_user = Accounts.get_account_user(user, account)

      {:ok, {_public_key, _}} =
        Accounts.create_api_key(account_user, %{name: "Public Key", type: :public})

      {:ok, {private_key, _}} =
        Accounts.create_api_key(account_user, %{name: "Private Key", type: :private})

      result = Accounts.list_all_api_keys(type: :private)

      assert length(result.api_keys) == 1
      assert hd(result.api_keys).name == private_key.name
    end
  end

  describe "list_all_account_users/0" do
    test "returns all account users with preloads" do
      user1 = user_fixture()
      user2 = user_fixture()
      _account1 = account_fixture(user1, %{name: "Account A"})
      _account2 = account_fixture(user2, %{name: "Account B"})

      result = Accounts.list_all_account_users()

      # Should have at least 2 account users
      assert length(result) >= 2

      # Each should have preloaded user and account
      Enum.each(result, fn au ->
        assert au.user.email
        assert au.account.name
      end)
    end
  end

  describe "get_user_accounts/1" do
    test "returns all accounts user belongs to with roles" do
      user = user_fixture()
      # user_fixture creates a default "Personal" account where user is owner
      account2 = account_fixture(user, %{name: "Work Account"})

      accounts = Accounts.get_user_accounts(user)

      assert length(accounts) == 2
      # Sorted by name: "Personal" < "Work Account"
      [{personal_account, personal_role}, {work_account, work_role}] = accounts

      assert personal_account.name == "Personal"
      assert personal_role == :owner
      assert work_account.id == account2.id
      assert work_role == :owner
    end

    test "returns accounts sorted by name" do
      user = user_fixture()
      # user_fixture creates "Personal" account
      _z_account = account_fixture(user, %{name: "Zebra Corp"})
      _a_account = account_fixture(user, %{name: "Acme Inc"})

      accounts = Accounts.get_user_accounts(user)
      names = Enum.map(accounts, fn {acc, _role} -> acc.name end)

      # Should be sorted alphabetically
      assert names == ["Acme Inc", "Personal", "Zebra Corp"]
    end
  end

  describe "get_account_user_by_id/2" do
    test "returns account_user with preloaded account" do
      user = user_fixture()
      account = account_fixture(user, %{name: "Test Account"})

      account_user = Accounts.get_account_user_by_id(user, account.id)

      assert account_user.user_id == user.id
      assert account_user.account_id == account.id
      assert account_user.account.name == "Test Account"
      assert account_user.role == :owner
    end

    test "returns nil when user is not a member" do
      user1 = user_fixture()
      user2 = user_fixture()
      account = account_fixture(user1, %{name: "User1's Account"})

      account_user = Accounts.get_account_user_by_id(user2, account.id)

      assert is_nil(account_user)
    end

    test "returns nil for non-existent account" do
      user = user_fixture()

      account_user = Accounts.get_account_user_by_id(user, Ecto.UUID.generate())

      assert is_nil(account_user)
    end
  end

  describe "Scope.for_user/1" do
    test "creates scope with user" do
      user = user_fixture()

      scope = Scope.for_user(user)

      assert scope.user.id == user.id
      assert is_nil(scope.account)
      assert is_nil(scope.account_user)
      assert scope.accounts == []
    end

    test "returns nil for nil user" do
      assert is_nil(Scope.for_user(nil))
    end
  end

  describe "Scope.with_account/4" do
    test "adds account context to scope" do
      user = user_fixture()
      account = account_fixture(user, %{name: "Test Account"})
      account_user = Accounts.get_account_user(user, account)
      accounts = Accounts.get_user_accounts(user)

      scope =
        user
        |> Scope.for_user()
        |> Scope.with_account(account, account_user, accounts)

      assert scope.user.id == user.id
      assert scope.account.id == account.id
      assert scope.account_user.id == account_user.id
      assert length(scope.accounts) >= 1
    end
  end

  describe "Scope.has_account?/1" do
    test "returns true when account is set" do
      user = user_fixture()
      account = account_fixture(user)
      account_user = Accounts.get_account_user(user, account)
      accounts = Accounts.get_user_accounts(user)

      scope =
        user
        |> Scope.for_user()
        |> Scope.with_account(account, account_user, accounts)

      assert Scope.has_account?(scope)
    end

    test "returns false when account is nil" do
      user = user_fixture()
      scope = Scope.for_user(user)

      refute Scope.has_account?(scope)
    end

    test "returns false for nil scope" do
      refute Scope.has_account?(nil)
    end
  end

  describe "Scope.can_view_account?/1" do
    test "returns true when user has any membership" do
      user = user_fixture()
      account = account_fixture(user)
      account_user = Accounts.get_account_user(user, account)
      accounts = Accounts.get_user_accounts(user)

      scope =
        user
        |> Scope.for_user()
        |> Scope.with_account(account, account_user, accounts)

      assert Scope.can_view_account?(scope)
    end

    test "returns false when account_user is nil" do
      user = user_fixture()
      scope = Scope.for_user(user)

      refute Scope.can_view_account?(scope)
    end

    test "returns false for nil scope" do
      refute Scope.can_view_account?(nil)
    end
  end

  describe "Scope.can_manage_account?/1" do
    test "returns true for owner" do
      user = user_fixture()
      account = account_fixture(user)
      account_user = Accounts.get_account_user(user, account)
      accounts = Accounts.get_user_accounts(user)

      scope =
        user
        |> Scope.for_user()
        |> Scope.with_account(account, account_user, accounts)

      assert scope.account_user.role == :owner
      assert Scope.can_manage_account?(scope)
    end

    test "returns true for admin" do
      owner = user_fixture()
      account = account_fixture(owner)
      admin = user_fixture()
      {:ok, _} = Accounts.add_user_to_account(account, admin, :admin)

      account_user = Accounts.get_account_user(admin, account)
      accounts = Accounts.get_user_accounts(admin)

      scope =
        admin
        |> Scope.for_user()
        |> Scope.with_account(account, account_user, accounts)

      assert scope.account_user.role == :admin
      assert Scope.can_manage_account?(scope)
    end

    test "returns false for member" do
      owner = user_fixture()
      account = account_fixture(owner)
      member = user_fixture()
      {:ok, _} = Accounts.add_user_to_account(account, member, :member)

      account_user = Accounts.get_account_user(member, account)
      accounts = Accounts.get_user_accounts(member)

      scope =
        member
        |> Scope.for_user()
        |> Scope.with_account(account, account_user, accounts)

      assert scope.account_user.role == :member
      refute Scope.can_manage_account?(scope)
    end

    test "returns false when account_user is nil" do
      user = user_fixture()
      scope = Scope.for_user(user)

      refute Scope.can_manage_account?(scope)
    end
  end

  describe "Scope.is_owner?/1" do
    test "returns true for owner" do
      user = user_fixture()
      account = account_fixture(user)
      account_user = Accounts.get_account_user(user, account)
      accounts = Accounts.get_user_accounts(user)

      scope =
        user
        |> Scope.for_user()
        |> Scope.with_account(account, account_user, accounts)

      assert Scope.is_owner?(scope)
    end

    test "returns false for admin" do
      owner = user_fixture()
      account = account_fixture(owner)
      admin = user_fixture()
      {:ok, _} = Accounts.add_user_to_account(account, admin, :admin)

      account_user = Accounts.get_account_user(admin, account)
      accounts = Accounts.get_user_accounts(admin)

      scope =
        admin
        |> Scope.for_user()
        |> Scope.with_account(account, account_user, accounts)

      refute Scope.is_owner?(scope)
    end

    test "returns false for member" do
      owner = user_fixture()
      account = account_fixture(owner)
      member = user_fixture()
      {:ok, _} = Accounts.add_user_to_account(account, member, :member)

      account_user = Accounts.get_account_user(member, account)
      accounts = Accounts.get_user_accounts(member)

      scope =
        member
        |> Scope.for_user()
        |> Scope.with_account(account, account_user, accounts)

      refute Scope.is_owner?(scope)
    end
  end
end
