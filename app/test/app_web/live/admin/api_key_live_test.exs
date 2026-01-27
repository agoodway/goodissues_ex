defmodule FFWeb.Admin.ApiKeyLiveTest do
  use FFWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import FF.AccountsFixtures

  alias FF.Accounts

  describe "Index (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/admin/api-keys")
      assert path =~ "/users/log-in"
    end
  end

  describe "Index (non-admin user)" do
    setup :register_and_log_in_user

    test "redirects to home when user is not an admin", %{conn: conn} do
      {:error, {:redirect, %{to: path, flash: flash}}} = live(conn, ~p"/admin/api-keys")
      assert path == "/"
      assert flash["error"] =~ "administrator"
    end
  end

  describe "Index (admin user)" do
    setup :register_and_log_in_admin_user

    test "lists all API keys", %{conn: conn} do
      user = user_fixture()
      account = account_fixture(user, %{name: "Test Account"})
      {_token, api_key} = api_key_fixture(user, account)

      {:ok, _index_live, html} = live(conn, ~p"/admin/api-keys")

      assert html =~ "API Keys"
      assert html =~ api_key.name
      assert html =~ user.email
      assert html =~ "Test Account"
    end

    test "shows empty state when no API keys exist", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/admin/api-keys")

      assert html =~ "API Keys"
      assert html =~ "No API keys found"
    end

    test "filters API keys by status", %{conn: conn} do
      user = user_fixture()
      account = account_fixture(user)
      account_user = Accounts.get_account_user(user, account)

      {:ok, {active_key, _}} =
        Accounts.create_api_key(account_user, %{name: "Active Test Key", type: :private})

      {:ok, {revoked_key, _}} =
        Accounts.create_api_key(account_user, %{name: "Revoked Test Key", type: :private})

      Accounts.revoke_api_key(revoked_key)

      {:ok, index_live, _html} = live(conn, ~p"/admin/api-keys")

      # Filter by revoked
      html =
        index_live
        |> form("form[phx-change='filter_status']", %{status: "revoked"})
        |> render_change()

      assert html =~ revoked_key.name
      refute html =~ active_key.name
    end

    test "filters API keys by type", %{conn: conn} do
      user = user_fixture()
      account = account_fixture(user)
      account_user = Accounts.get_account_user(user, account)

      {:ok, {public_key, _token}} =
        Accounts.create_api_key(account_user, %{name: "Public Key", type: :public})

      {:ok, {private_key, _token}} =
        Accounts.create_api_key(account_user, %{name: "Private Key", type: :private})

      {:ok, index_live, _html} = live(conn, ~p"/admin/api-keys")

      # Filter by private
      html =
        index_live
        |> form("form[phx-change='filter_type']", %{type: "private"})
        |> render_change()

      assert html =~ private_key.name
      refute html =~ public_key.name
    end

    test "searches API keys by name", %{conn: conn} do
      user = user_fixture()
      account = account_fixture(user)
      account_user = Accounts.get_account_user(user, account)

      {:ok, {findable_key, _token}} =
        Accounts.create_api_key(account_user, %{name: "Findable Key", type: :private})

      {:ok, {other_key, _token}} =
        Accounts.create_api_key(account_user, %{name: "Other Key", type: :private})

      {:ok, index_live, _html} = live(conn, ~p"/admin/api-keys")

      html =
        index_live
        |> form("form[phx-submit='search']", %{search: "Findable"})
        |> render_change()

      assert html =~ findable_key.name
      refute html =~ other_key.name
    end

    test "revokes an active API key", %{conn: conn} do
      user = user_fixture()
      account = account_fixture(user)
      {_token, api_key} = api_key_fixture(user, account)

      {:ok, index_live, _html} = live(conn, ~p"/admin/api-keys")

      assert index_live
             |> element("button[phx-click='revoke'][phx-value-id='#{api_key.id}']")
             |> render_click() =~ "API key revoked"

      # Verify in database
      updated_key = Accounts.get_api_key!(api_key.id)
      assert updated_key.status == :revoked
    end

    test "navigates to new API key page", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/api-keys")

      {:ok, _new_live, html} =
        index_live
        |> element("a[href='/admin/api-keys/new']")
        |> render_click()
        |> follow_redirect(conn, ~p"/admin/api-keys/new")

      assert html =~ "New API Key"
    end
  end

  describe "Show (admin user)" do
    setup :register_and_log_in_admin_user

    test "displays API key details", %{conn: conn} do
      user = user_fixture()
      account = account_fixture(user, %{name: "Detail Account"})
      {_token, api_key} = api_key_fixture(user, account)

      {:ok, _show_live, html} = live(conn, ~p"/admin/api-keys/#{api_key.id}")

      assert html =~ api_key.name
      assert html =~ api_key.token_prefix
      assert html =~ user.email
      assert html =~ "Detail Account"
    end

    test "revokes API key from show page", %{conn: conn} do
      user = user_fixture()
      account = account_fixture(user)
      {_token, api_key} = api_key_fixture(user, account)

      {:ok, show_live, _html} = live(conn, ~p"/admin/api-keys/#{api_key.id}")

      assert show_live
             |> element("button[phx-click='revoke']")
             |> render_click() =~ "API key revoked"

      updated_key = Accounts.get_api_key!(api_key.id)
      assert updated_key.status == :revoked
    end

    test "does not show revoke button for revoked keys", %{conn: conn} do
      user = user_fixture()
      account = account_fixture(user)
      {_token, api_key} = api_key_fixture(user, account)
      Accounts.revoke_api_key(api_key)

      {:ok, _show_live, html} = live(conn, ~p"/admin/api-keys/#{api_key.id}")

      refute html =~ "phx-click=\"revoke\""
      assert html =~ "revoked"
    end
  end

  describe "New (admin user)" do
    setup :register_and_log_in_admin_user

    test "displays create form", %{conn: conn} do
      {:ok, _new_live, html} = live(conn, ~p"/admin/api-keys/new")

      assert html =~ "New API Key"
      assert html =~ "Name"
      assert html =~ "Owner"
      assert html =~ "Type"
    end

    test "validates required fields", %{conn: conn} do
      # Create at least one account_user so the form can be submitted
      user = user_fixture()
      _account = account_fixture(user)

      {:ok, new_live, _html} = live(conn, ~p"/admin/api-keys/new")

      html =
        new_live
        |> form("#api-key-form", api_key: %{name: ""})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "creates API key and shows token", %{conn: conn} do
      user = user_fixture()
      account = account_fixture(user, %{name: "New Key Account"})
      account_user = Accounts.get_account_user(user, account)

      {:ok, new_live, _html} = live(conn, ~p"/admin/api-keys/new")

      html =
        new_live
        |> form("#api-key-form",
          api_key: %{
            name: "Created Key",
            account_user_id: account_user.id,
            type: "private"
          }
        )
        |> render_submit()

      assert html =~ "API key created successfully"
      assert html =~ "Save this token now"
      assert html =~ "sk_"
      assert html =~ "Created Key"
    end

    test "shows warning about token not being retrievable", %{conn: conn} do
      user = user_fixture()
      account = account_fixture(user)
      account_user = Accounts.get_account_user(user, account)

      {:ok, new_live, _html} = live(conn, ~p"/admin/api-keys/new")

      html =
        new_live
        |> form("#api-key-form",
          api_key: %{
            name: "Warning Test Key",
            account_user_id: account_user.id,
            type: "public"
          }
        )
        |> render_submit()

      assert html =~ "cannot be retrieved later"
    end
  end
end
