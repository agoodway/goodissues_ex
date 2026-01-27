defmodule FFWeb.Plugs.ApiAuth do
  @moduledoc """
  Bearer token authentication for API requests.
  Validates API keys and loads user/account context.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias FF.Accounts

  def init(opts), do: opts

  @doc """
  Main plug function - dispatches based on opts.
  """
  def call(conn, opts) do
    case opts do
      :require_write_access -> require_write_access(conn, [])
      _ -> require_api_auth(conn, opts)
    end
  end

  @doc """
  Requires API authentication via bearer token.
  Extracts token from Authorization header, verifies it, and loads context.
  """
  def require_api_auth(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, api_key} <- Accounts.verify_api_token(token),
         :ok <- check_user_confirmed(api_key.account_user.user),
         :ok <- check_account_active(api_key.account_user.account) do
      # Update last_used_at timestamp (async in prod, sync in test)
      if Mix.env() == :test do
        Accounts.touch_api_key(api_key)
      else
        Task.start(fn -> Accounts.touch_api_key(api_key) end)
      end

      conn
      |> assign(:current_api_key, api_key)
      |> assign(:current_account_user, api_key.account_user)
      |> assign(:current_user, api_key.account_user.user)
      |> assign(:current_account, api_key.account_user.account)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> put_view(json: FFWeb.ErrorJSON)
        |> render(:"401")
        |> halt()
    end
  end

  @doc """
  Requires write access (private API key with sk_ prefix).
  Must be used after require_api_auth/2.
  """
  def require_write_access(conn, _opts) do
    api_key = conn.assigns[:current_api_key]

    if api_key && api_key.type == :private do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> put_view(json: FFWeb.ErrorJSON)
      |> render(:"403")
      |> halt()
    end
  end

  defp check_user_confirmed(%{confirmed_at: nil}), do: {:error, :unconfirmed}
  defp check_user_confirmed(_user), do: :ok

  defp check_account_active(%{status: :active}), do: :ok
  defp check_account_active(_), do: {:error, :account_suspended}
end
