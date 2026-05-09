defmodule GIWeb.MCP.Plug do
  @moduledoc """
  Authenticates MCP requests using Bearer token.

  Validates early before forwarding to Anubis server.
  """
  import Plug.Conn
  alias GI.Accounts

  alias Anubis.Server.Transport.StreamableHTTP.Plug, as: AnubisPlug

  def init(opts) do
    # Initialize Anubis plug with our options
    AnubisPlug.init(opts)
  end

  def call(conn, anubis_opts) do
    with {:ok, token} <- extract_bearer_token(conn),
         {:ok, _api_key} <- Accounts.verify_api_token(token) do
      # Forward to Anubis server
      AnubisPlug.call(conn, anubis_opts)
    else
      {:error, :missing_auth} ->
        send_error(conn, 401, "Authorization header with Bearer token is required")

      {:error, :invalid_format} ->
        send_error(conn, 401, "Invalid Authorization header format. Expected: Bearer <token>")

      {:error, _reason} ->
        send_error(conn, 401, "Invalid or expired API key")
    end
  end

  defp extract_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] when byte_size(token) > 0 ->
        {:ok, token}

      ["Bearer " <> _] ->
        {:error, :invalid_format}

      [_other] ->
        {:error, :invalid_format}

      [] ->
        {:error, :missing_auth}
    end
  end

  defp send_error(conn, status, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(%{error: message}))
    |> halt()
  end
end
