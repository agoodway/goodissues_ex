defmodule GIWeb.Plugs.ApiAuth do
  @moduledoc """
  Bearer token authentication for API requests.
  Validates API keys and loads user/account context.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias GI.Accounts

  @env Application.compile_env(:good_issues, :env, :prod)

  # Suppress dialyzer warning - the else branch is reachable in dev/prod
  @dialyzer {:nowarn_function, touch_api_key_async: 1}

  def init(opts), do: opts

  @doc """
  Main plug function - dispatches based on opts.
  """
  def call(conn, opts) do
    case opts do
      :require_write_access -> require_write_access(conn, [])
      {:require_scope, scope} -> require_scope(conn, scope)
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
      touch_api_key_async(api_key)

      conn
      |> assign(:current_api_key, api_key)
      |> assign(:current_account_user, api_key.account_user)
      |> assign(:current_user, api_key.account_user.user)
      |> assign(:current_account, api_key.account_user.account)
    else
      _ ->
        halt_unauthorized(conn)
    end
  end

  defp touch_api_key_async(api_key) do
    # Update last_used_at timestamp (async in prod, sync in test)
    if @env == :test do
      Accounts.touch_api_key(api_key)
    else
      Task.start(fn -> Accounts.touch_api_key(api_key) end)
    end
  end

  defp halt_unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: GIWeb.ErrorJSON)
    |> render(:"401")
    |> halt()
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
      |> put_view(json: GIWeb.ErrorJSON)
      |> render(:"403")
      |> halt()
    end
  end

  @doc """
  Requires a specific scope on the API key.
  Must be used after require_api_auth/2.

  Empty scopes on the API key means "all access" (no restrictions).

  ## Examples

      plug GIWeb.Plugs.ApiAuth, {:require_scope, "projects:read"}
      plug GIWeb.Plugs.ApiAuth, {:require_scope, "issues:write"}
  """
  def require_scope(conn, required_scope) do
    case conn.assigns[:current_api_key] do
      nil ->
        # No API key means no authentication - return forbidden
        conn
        |> put_status(:forbidden)
        |> put_view(json: GIWeb.ErrorJSON)
        |> render(:forbidden_scope, scope: required_scope)
        |> halt()

      api_key ->
        scopes = api_key.scopes || []

        # Empty scopes means "all access" - no restrictions
        if scopes == [] or required_scope in scopes do
          conn
        else
          conn
          |> put_status(:forbidden)
          |> put_view(json: GIWeb.ErrorJSON)
          |> render(:forbidden_scope, scope: required_scope)
          |> halt()
        end
    end
  end

  defp check_user_confirmed(%{confirmed_at: nil}), do: {:error, :unconfirmed}
  defp check_user_confirmed(_user), do: :ok

  defp check_account_active(%{status: :active}), do: :ok
  defp check_account_active(_), do: {:error, :account_suspended}
end
