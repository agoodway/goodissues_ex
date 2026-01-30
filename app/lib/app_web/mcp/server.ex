defmodule FFWeb.MCP.Server do
  @moduledoc """
  MCP server implementation using Anubis.

  Authenticates clients via Bearer token and exposes tools.
  """
  use Anubis.Server,
    name: "fruitfly",
    version: "1.0.0",
    capabilities: [:tools]

  alias FF.Accounts
  alias Anubis.Server.Frame

  # Register tool components at compile time
  component(FFWeb.MCP.Tools.Projects.ProjectsList, name: "projects_list")
  component(FFWeb.MCP.Tools.Projects.ProjectsGet, name: "projects_get")
  component(FFWeb.MCP.Tools.Issues.IssuesList, name: "issues_list")
  component(FFWeb.MCP.Tools.Issues.IssuesGet, name: "issues_get")
  component(FFWeb.MCP.Tools.Issues.IssuesCreate, name: "issues_create")
  component(FFWeb.MCP.Tools.Issues.IssuesUpdate, name: "issues_update")

  @impl true
  def init(_client_info, frame) do
    case extract_and_authenticate(frame) do
      {:ok, api_key} ->
        {:ok, Frame.assign(frame, :api_key, api_key)}

      {:error, _reason} ->
        {:stop, :unauthorized}
    end
  end

  # Private helpers

  defp extract_and_authenticate(frame) do
    with {:ok, auth_header} <- get_auth_header(frame),
         {:ok, token} <- extract_bearer_token(auth_header),
         {:ok, api_key} <- Accounts.verify_api_token(token) do
      {:ok, api_key}
    else
      error -> error
    end
  end

  defp get_auth_header(frame) do
    case frame.transport do
      %{req_headers: headers} when is_map(headers) ->
        cond do
          Map.has_key?(headers, "authorization") -> {:ok, headers["authorization"]}
          Map.has_key?(headers, "Authorization") -> {:ok, headers["Authorization"]}
          true -> {:error, :missing_auth}
        end

      %{req_headers: headers} when is_list(headers) ->
        case List.keyfind(headers, "authorization", 0) do
          {_, value} -> {:ok, value}
          nil -> {:error, :missing_auth}
        end

      _ ->
        {:error, :missing_auth}
    end
  end

  defp extract_bearer_token("Bearer " <> token) when byte_size(token) > 0 do
    {:ok, token}
  end

  defp extract_bearer_token(_), do: {:error, :invalid_format}
end
