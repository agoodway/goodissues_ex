defmodule FFWeb.Plugs.AdminAuth do
  @moduledoc """
  Plug for admin-only routes.
  Requires the user to be an admin (is_admin == true).
  Must be used after fetch_current_scope_for_user.
  """
  import Plug.Conn
  import Phoenix.Controller

  use FFWeb, :verified_routes

  def init(opts), do: opts

  def call(conn, _opts) do
    if admin?(conn.assigns[:current_scope]) do
      conn
    else
      conn
      |> put_flash(:error, "You must be an administrator to access this page.")
      |> redirect(to: ~p"/")
      |> halt()
    end
  end

  defp admin?(%{user: %{is_admin: true}}), do: true
  defp admin?(_), do: false
end
