defmodule FFWeb.Dashboard.ApiKeyLiveTest do
  use FFWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import FF.AccountsFixtures

  alias FF.Accounts

  describe "Index (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/dashboard/test-account/api-keys")
      assert path =~ "/users/log-in"
    end
  end

  describe "Index (authenticated user)" do
    setup :register_and_log_in_user_with_account

    test "shows only API keys for the current account", %{
      conn: conn,
      user: user,
      account: account
    } do
      # Create API key for user's account with a unique name
      account_user = Accounts.get_account_user(user, account)

      {:ok, {my_api_key, _token}} =
        Accounts.create_api_key(account_user, %{name: "My Account Key", type: :private})

      # Create API key for a different account with a different unique name
      other_user = user_fixture()
      other_account = account_fixture(other_user, %{name: "Other Account"})
      other_account_user = Accounts.get_account_user(other_user, other_account)

      {:ok, {other_api_key, _token}} =
        Accounts.create_api_key(other_account_user, %{name: "Other Account Key", type: :private})

      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/api-keys")

      assert html =~ "API Keys"
      assert html =~ my_api_key.name
      refute html =~ other_api_key.name
      refute html =~ "Other Account"
    end

    test "shows empty state when no API keys exist for account", %{conn: conn, account: account} do
      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/api-keys")

      assert html =~ "API Keys"
      assert html =~ "No API keys found"
    end

    test "filters API keys by status", %{conn: conn, user: user, account: account} do
      account_user = Accounts.get_account_user(user, account)

      {:ok, {active_key, _}} =
        Accounts.create_api_key(account_user, %{name: "Active Test Key", type: :private})

      {:ok, {revoked_key, _}} =
        Accounts.create_api_key(account_user, %{name: "Revoked Test Key", type: :private})

      Accounts.revoke_api_key(revoked_key)

      {:ok, index_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/api-keys")

      # Filter by revoked
      html =
        index_live
        |> form("form[phx-change='filter_status']", %{status: "revoked"})
        |> render_change()

      assert html =~ revoked_key.name
      refute html =~ active_key.name
    end

    test "filters API keys by type", %{conn: conn, user: user, account: account} do
      account_user = Accounts.get_account_user(user, account)

      {:ok, {public_key, _token}} =
        Accounts.create_api_key(account_user, %{name: "Public Key", type: :public})

      {:ok, {private_key, _token}} =
        Accounts.create_api_key(account_user, %{name: "Private Key", type: :private})

      {:ok, index_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/api-keys")

      # Filter by private
      html =
        index_live
        |> form("form[phx-change='filter_type']", %{type: "private"})
        |> render_change()

      assert html =~ private_key.name
      refute html =~ public_key.name
    end

    test "searches API keys by name", %{conn: conn, user: user, account: account} do
      account_user = Accounts.get_account_user(user, account)

      {:ok, {findable_key, _token}} =
        Accounts.create_api_key(account_user, %{name: "Findable Key", type: :private})

      {:ok, {other_key, _token}} =
        Accounts.create_api_key(account_user, %{name: "Other Key", type: :private})

      {:ok, index_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/api-keys")

      html =
        index_live
        |> form("form[phx-submit='search']", %{search: "Findable"})
        |> render_change()

      assert html =~ findable_key.name
      refute html =~ other_key.name
    end
  end

  describe "Index (owner/admin can manage)" do
    setup :register_and_log_in_user_with_account

    test "owner can revoke API keys", %{conn: conn, user: user, account: account} do
      {_token, api_key} = api_key_fixture(user, account)

      {:ok, index_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/api-keys")

      assert index_live
             |> element("button[phx-click='revoke'][phx-value-id='#{api_key.id}']")
             |> render_click() =~ "API key revoked"

      # Verify in database
      updated_key = Accounts.get_api_key!(api_key.id)
      assert updated_key.status == :revoked
    end

    test "owner sees 'New API Key' button", %{conn: conn, account: account} do
      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/api-keys")

      assert html =~ "New API Key"
    end
  end

  describe "Index (member cannot manage)" do
    setup do
      owner = user_fixture()
      account = account_fixture(owner, %{name: "Member Test Account"})
      member = user_fixture()
      {:ok, _account_user} = Accounts.add_user_to_account(account, member, :member)

      conn =
        build_conn()
        |> log_in_user(member)

      %{conn: conn, member: member, account: account, owner: owner}
    end

    test "member cannot revoke API keys", %{conn: conn, owner: owner, account: account} do
      {_token, api_key} = api_key_fixture(owner, account)

      {:ok, index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/api-keys")

      # Should see the API key but not the revoke button
      assert html =~ api_key.name
      refute has_element?(index_live, "button[phx-click='revoke'][phx-value-id='#{api_key.id}']")
    end

    test "member does not see 'New API Key' button", %{conn: conn, account: account} do
      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/api-keys")

      refute html =~ ~s(href="/dashboard/#{account.slug}/api-keys/new")
      assert html =~ "read-only access"
    end
  end

  describe "Show (authenticated user)" do
    setup :register_and_log_in_user_with_account

    test "displays API key details for current account", %{
      conn: conn,
      user: user,
      account: account
    } do
      {_token, api_key} = api_key_fixture(user, account)

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/#{account.slug}/api-keys/#{api_key.id}")

      assert html =~ api_key.name
      assert html =~ api_key.token_prefix
      assert html =~ user.email
    end

    test "redirects when API key belongs to different account", %{conn: conn, account: account} do
      other_user = user_fixture()
      other_account = account_fixture(other_user, %{name: "Other Account"})
      {_token, other_api_key} = api_key_fixture(other_user, other_account)

      {:error, {:live_redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/dashboard/#{account.slug}/api-keys/#{other_api_key.id}")

      assert path == "/dashboard/#{account.slug}/api-keys"
      assert flash["error"] == "API key not found."
    end

    test "owner can revoke API key from show page", %{conn: conn, user: user, account: account} do
      {_token, api_key} = api_key_fixture(user, account)

      {:ok, show_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/api-keys/#{api_key.id}")

      assert show_live
             |> element("button[phx-click='revoke']")
             |> render_click() =~ "API key revoked"

      updated_key = Accounts.get_api_key!(api_key.id)
      assert updated_key.status == :revoked
    end

    test "does not show revoke button for revoked keys", %{
      conn: conn,
      user: user,
      account: account
    } do
      {_token, api_key} = api_key_fixture(user, account)
      Accounts.revoke_api_key(api_key)

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/#{account.slug}/api-keys/#{api_key.id}")

      refute html =~ "phx-click=\"revoke\""
      assert html =~ "revoked"
    end
  end

  describe "New (owner/admin)" do
    setup :register_and_log_in_user_with_account

    test "displays create form with current account info", %{
      conn: conn,
      user: user,
      account: account
    } do
      {:ok, _new_live, html} = live(conn, ~p"/dashboard/#{account.slug}/api-keys/new")

      assert html =~ "New API Key"
      assert html =~ "Name"
      assert html =~ "Type"
      assert html =~ user.email
      assert html =~ account.name
    end

    test "validates required fields", %{conn: conn, account: account} do
      {:ok, new_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/api-keys/new")

      html =
        new_live
        |> form("#api-key-form", api_key: %{name: ""})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "creates API key and shows token", %{conn: conn, account: account} do
      {:ok, new_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/api-keys/new")

      html =
        new_live
        |> form("#api-key-form",
          api_key: %{
            name: "Created Key",
            type: "private"
          }
        )
        |> render_submit()

      assert html =~ "API key created successfully"
      assert html =~ "Save this token now"
      assert html =~ "sk_"
      assert html =~ "Created Key"
      assert html =~ account.name
    end
  end

  describe "New (member cannot access)" do
    setup do
      owner = user_fixture()
      account = account_fixture(owner, %{name: "Member Test Account"})
      member = user_fixture()
      {:ok, _account_user} = Accounts.add_user_to_account(account, member, :member)

      conn =
        build_conn()
        |> log_in_user(member)

      %{conn: conn, member: member, account: account}
    end

    test "member is redirected when trying to create API key", %{conn: conn, account: account} do
      {:error, {:live_redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/dashboard/#{account.slug}/api-keys/new")

      assert path == "/dashboard/#{account.slug}/api-keys"
      assert flash["error"] == "You don't have permission to create API keys."
    end
  end
end
