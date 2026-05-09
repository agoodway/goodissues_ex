defmodule GIWeb.DashboardController do
  use GIWeb, :controller

  alias GI.Accounts

  @doc """
  Redirects to the user's first account dashboard.

  If the user has no accounts, redirects to home with an error message.
  """
  def index(conn, _params) do
    user = conn.assigns.current_scope.user
    accounts = Accounts.get_user_accounts(user)

    case accounts do
      [] ->
        conn
        |> put_flash(:error, "You need to be a member of an account to access the dashboard.")
        |> redirect(to: ~p"/")

      [{account, _role} | _] ->
        redirect(conn, to: ~p"/dashboard/#{account.slug}")
    end
  end
end
