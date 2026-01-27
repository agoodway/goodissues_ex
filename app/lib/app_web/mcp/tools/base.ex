defmodule FFWeb.MCP.Tools.Base do
  @moduledoc """
  Shared utilities for all MCP tools.
  """
  alias Hermes.Server.Response

  @doc "Wraps tool execution with scope validation"
  def with_scope(state, required_scope, fun) do
    case validate_scope(state, required_scope) do
      {:ok, api_key} ->
        try do
          fun.(api_key)
        rescue
          Ecto.NoResultsError ->
            {:reply, error_response("Resource not found"), state}

          e ->
            require Logger
            Logger.error("Tool execution error: #{inspect(e)}")
            {:reply, error_response("Internal server error"), state}
        end

      {:error, message} ->
        {:reply, error_response(message), state}
    end
  end

  defp validate_scope(state, required_scope) do
    case state[:api_key] do
      nil ->
        {:error, "Authentication required"}

      api_key ->
        if required_scope in (api_key.scopes || []) do
          {:ok, api_key}
        else
          {:error, "Insufficient permissions. Required scope: #{required_scope}"}
        end
    end
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

  @doc "Get pagination from arguments"
  def get_pagination(args) do
    page = Map.get(args, "page", 1) |> ensure_positive_integer(1)
    per_page = Map.get(args, "per_page", 50) |> ensure_positive_integer(50) |> min(250)
    {page, per_page}
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
