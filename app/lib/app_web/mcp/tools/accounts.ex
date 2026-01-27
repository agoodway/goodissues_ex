defmodule FFWeb.MCP.Tools.Accounts do
  @moduledoc """
  MCP tools for account management operations.
  """
  alias FFWeb.MCP.Tools.Base
  alias FF.Accounts
  alias FF.Repo
  alias Hermes.Server.Component.Tool
  import Ecto.Query

  @doc "List all available tools in this module"
  def tools do
    [
      %Tool{
        name: "accounts_list",
        description: "List accounts with pagination",
        input_schema: %{
          "type" => "object",
          "properties" => Base.pagination_schema()
        }
      },
      %Tool{
        name: "accounts_get",
        description: "Get a single account by ID",
        input_schema: %{
          "type" => "object",
          "required" => ["id"],
          "properties" => %{
            "id" => %{
              "type" => "string",
              "description" => "Account ID"
            }
          }
        }
      },
      %Tool{
        name: "accounts_users_list",
        description: "List users in an account with pagination",
        input_schema: %{
          "type" => "object",
          "required" => ["account_id"],
          "properties" =>
            Map.merge(
              Base.pagination_schema(),
              %{
                "account_id" => %{
                  "type" => "string",
                  "description" => "Account ID"
                }
              }
            )
        }
      },
      %Tool{
        name: "api_keys_list",
        description: "List API keys for the current user's account membership",
        input_schema: %{
          "type" => "object",
          "properties" => Base.pagination_schema()
        }
      }
    ]
  end

  @doc "Handle tool execution"
  @spec handle(String.t(), map(), map()) :: {:reply, Hermes.Server.Response.t(), map()}

  def handle("accounts_list", args, state) do
    Base.with_scope(state, "accounts:read", fn _api_key ->
      {page, per_page} = Base.get_pagination(args)

      {accounts, total} = list_accounts(page, per_page)
      data = Enum.map(accounts, &serialize_account/1)
      meta = Base.build_meta(page, per_page, total)

      {:reply, Base.list_response(data, meta), state}
    end)
  end

  def handle("accounts_get", %{"id" => id}, state) do
    Base.with_scope(state, "accounts:read", fn _api_key ->
      case Accounts.get_account(id) do
        nil ->
          {:reply, Base.error_response("Account not found"), state}

        account ->
          {:reply, Base.success_response(serialize_account(account)), state}
      end
    end)
  end

  def handle("accounts_users_list", args, state) do
    Base.with_scope(state, "accounts:read", fn _api_key ->
      account_id = Map.fetch!(args, "account_id")
      {page, per_page} = Base.get_pagination(args)

      {users, total} = list_account_users(account_id, page, per_page)
      data = Enum.map(users, &serialize_account_user/1)
      meta = Base.build_meta(page, per_page, total)

      {:reply, Base.list_response(data, meta), state}
    end)
  end

  def handle("api_keys_list", args, state) do
    Base.with_scope(state, "api_keys:read", fn api_key ->
      {page, per_page} = Base.get_pagination(args)

      {keys, total} = list_api_keys(api_key.account_user_id, page, per_page)
      data = Enum.map(keys, &serialize_api_key/1)
      meta = Base.build_meta(page, per_page, total)

      {:reply, Base.list_response(data, meta), state}
    end)
  end

  # Private helpers

  defp list_accounts(page, per_page) do
    query = from(a in Accounts.Account, order_by: [desc: a.inserted_at])

    total = Repo.aggregate(query, :count)

    accounts =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    {accounts, total}
  end

  defp list_account_users(account_id, page, per_page) do
    query =
      from(au in Accounts.AccountUser,
        where: au.account_id == ^account_id,
        preload: [:user],
        order_by: [desc: au.inserted_at]
      )

    total = Repo.aggregate(query, :count)

    users =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    {users, total}
  end

  defp list_api_keys(account_user_id, page, per_page) do
    query =
      from(k in Accounts.ApiKey,
        where: k.account_user_id == ^account_user_id,
        order_by: [desc: k.inserted_at]
      )

    total = Repo.aggregate(query, :count)

    keys =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    {keys, total}
  end

  defp serialize_account(account) do
    %{
      id: account.id,
      name: account.name,
      inserted_at: DateTime.to_iso8601(account.inserted_at),
      updated_at: DateTime.to_iso8601(account.updated_at)
    }
  end

  defp serialize_account_user(account_user) do
    %{
      id: account_user.id,
      role: account_user.role,
      user: %{
        id: account_user.user.id,
        email: account_user.user.email
      },
      inserted_at: DateTime.to_iso8601(account_user.inserted_at)
    }
  end

  defp serialize_api_key(api_key) do
    %{
      id: api_key.id,
      name: api_key.name,
      type: api_key.type,
      token_prefix: api_key.token_prefix,
      status: api_key.status,
      scopes: api_key.scopes,
      last_used_at: api_key.last_used_at && DateTime.to_iso8601(api_key.last_used_at),
      expires_at: api_key.expires_at && DateTime.to_iso8601(api_key.expires_at),
      inserted_at: DateTime.to_iso8601(api_key.inserted_at)
    }
  end
end
