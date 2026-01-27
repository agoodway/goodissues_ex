defmodule FFWeb.DashboardControllerTest do
  use FFWeb.ConnCase, async: true

  import FF.AccountsFixtures

  setup :register_and_log_in_user

  describe "index/2" do
    test "redirects to user's first account dashboard", %{conn: conn, user: user} do
      # User already has an account from register_and_log_in_user
      accounts = FF.Accounts.get_user_accounts(user)
      {account, _role} = hd(accounts)

      conn = get(conn, ~p"/dashboard")

      assert redirected_to(conn) == ~p"/dashboard/#{account.slug}"
    end

    test "redirects to home with error if user has no accounts", %{conn: conn, user: _user} do
      # Remove user from all accounts (delete account_users)
      # For this test, we'll use a fresh user without accounts
      other_user = user_fixture()

      # Delete default account created during fixture
      accounts = FF.Accounts.get_user_accounts(other_user)

      for {account, _role} <- accounts do
        account_user = FF.Accounts.get_account_user(other_user, account)
        FF.Repo.delete!(account_user)
        FF.Repo.delete!(account)
      end

      conn =
        conn
        |> recycle()
        |> log_in_user(other_user)

      conn = get(conn, ~p"/dashboard")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "need to be a member of an account"
    end
  end
end
