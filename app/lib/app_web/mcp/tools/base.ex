defmodule FFWeb.MCP.Tools.Base do
  @moduledoc """
  Shared utilities for all MCP tools.
  """
  alias Anubis.Server.Response
  alias FF.Accounts

  @doc "Wraps tool execution with scope validation"
  def with_scope(frame, required_scope, fun) do
    case authenticate_and_validate_scope(frame, required_scope) do
      {:ok, api_key} ->
        try do
          fun.(api_key)
        rescue
          Ecto.NoResultsError ->
            {:reply, error_response("Resource not found"), frame.assigns}

          e ->
            require Logger
            Logger.error("Tool execution error: #{inspect(e)}")
            {:reply, error_response("Internal server error"), frame.assigns}
        end

      {:error, message} ->
        {:reply, error_response(message), frame.assigns}
    end
  end

  defp authenticate_and_validate_scope(frame, required_scope) do
    # First check if already authenticated in assigns
    case frame.assigns[:api_key] do
      nil ->
        # Authenticate from request headers
        authenticate_from_transport(frame, required_scope)

      api_key ->
        validate_scope(api_key, required_scope)
    end
  end

  defp authenticate_from_transport(frame, required_scope) do
    with {:ok, token} <- extract_bearer_token(frame.transport),
         {:ok, api_key} <- Accounts.verify_api_token(token) do
      validate_scope(api_key, required_scope)
    else
      {:error, :missing_auth} -> {:error, "Authentication required"}
      {:error, :invalid_format} -> {:error, "Invalid Authorization header format"}
      {:error, _} -> {:error, "Invalid or expired API key"}
    end
  end

  defp extract_bearer_token(%{req_headers: headers}) when is_map(headers) do
    auth = headers["authorization"] || headers["Authorization"]
    parse_bearer(auth)
  end

  defp extract_bearer_token(%{req_headers: headers}) when is_list(headers) do
    case List.keyfind(headers, "authorization", 0) do
      {_, value} -> parse_bearer(value)
      nil -> {:error, :missing_auth}
    end
  end

  defp extract_bearer_token(_), do: {:error, :missing_auth}

  defp parse_bearer("Bearer " <> token) when byte_size(token) > 0, do: {:ok, token}
  defp parse_bearer(_), do: {:error, :invalid_format}

  defp validate_scope(api_key, required_scope) do
    scopes = api_key.scopes || []

    # Empty scopes means "all access" - no restrictions
    if scopes == [] or required_scope in scopes do
      {:ok, api_key}
    else
      {:error, "Insufficient permissions. Required scope: #{required_scope}"}
    end
  end

  @doc "Extract account from API key"
  def get_account(api_key) do
    api_key.account_user.account
  end

  @doc "Extract user from API key"
  def get_user(api_key) do
    api_key.account_user.user
  end

  @doc "Success response format"
  def success_response(data) do
    Response.tool()
    |> Response.json(%{success: true, data: data})
  end

  @doc "List response with pagination metadata"
  def list_response(items, meta) do
    Response.tool()
    |> Response.json(%{success: true, data: items, meta: meta})
  end

  @doc "Error response format"
  def error_response(message) do
    Response.tool()
    |> Response.error(message)
  end

  @doc "Format changeset errors"
  def changeset_error_response(changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)

    error_response("Validation failed: #{Jason.encode!(errors)}")
  end

  @doc "Get pagination from arguments (supports both string and atom keys)"
  def get_pagination(args) do
    page = get_param(args, :page, "page", 1) |> ensure_positive_integer(1)

    per_page =
      get_param(args, :per_page, "per_page", 50) |> ensure_positive_integer(50) |> min(250)

    {page, per_page}
  end

  @doc "Get param with atom or string key"
  def get_param(args, atom_key, string_key, default) do
    Map.get(args, atom_key) || Map.get(args, string_key) || default
  end

  @doc "Build pagination metadata"
  def build_meta(page, per_page, total_count) do
    total_pages = ceil(total_count / per_page)

    %{
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages,
      has_next: page < total_pages,
      has_prev: page > 1
    }
  end

  @doc "Pagination schema for tool definitions"
  def pagination_schema do
    %{
      "page" => %{
        "type" => "integer",
        "description" => "Page number (1-indexed)",
        "minimum" => 1,
        "default" => 1
      },
      "per_page" => %{
        "type" => "integer",
        "description" => "Results per page (max 250)",
        "minimum" => 1,
        "maximum" => 250,
        "default" => 50
      }
    }
  end

  @doc "Escape LIKE wildcards to prevent SQL injection"
  def escape_like(nil), do: nil

  def escape_like(string) when is_binary(string) do
    string
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end

  defp ensure_positive_integer(value, _default) when is_integer(value) and value > 0, do: value
  defp ensure_positive_integer(_, default), do: default
end
