defmodule FFWeb.MCP.Server do
  @moduledoc """
  MCP server implementation using Hermes.

  Authenticates clients via Bearer token and exposes tools.
  """
  use Hermes.Server,
    name: "fruitfly",
    version: "1.0.0",
    capabilities: [:tools]

  alias FF.Accounts
  alias FFWeb.MCP.Tools
  alias Hermes.Server.Frame
  alias Hermes.Server.Response

  # List all tool modules here
  @tool_modules [
    Tools.Accounts
    # Add more tool modules as you create them
  ]

  # Build routing map at compile time
  @tool_routing @tool_modules
                |> Enum.flat_map(fn mod ->
                  Enum.map(mod.tools(), &{&1.name, mod})
                end)
                |> Map.new()

  @impl true
  def init(_client_info, frame) do
    # Extract and validate Bearer token
    case extract_and_authenticate(frame) do
      {:ok, api_key} ->
        # Store api_key in frame for tool access
        frame = assign(frame, :api_key, api_key)

        # Register all tools
        frame = register_all_tools(frame)

        # Register test tool
        frame =
          Frame.register_tool(frame, "hello_world",
            description: "Test tool that returns a greeting",
            input_schema: %{
              "type" => "object",
              "properties" => %{
                "name" => %{"type" => "string", "description" => "Name to greet"}
              }
            }
          )

        {:ok, frame}

      {:error, _reason} ->
        {:stop, :unauthorized}
    end
  end

  @impl true
  def handle_tool_call(tool_name, arguments, frame) do
    # Handle test tool
    if tool_name == "hello_world" do
      name = Map.get(arguments, "name", "World")

      response =
        Response.tool()
        |> Response.text("Hello, #{name}!")

      {:reply, response, frame}
    else
      # Route to appropriate tool module
      case Map.fetch(@tool_routing, tool_name) do
        {:ok, module} ->
          # Call tool handler with frame.assigns (containing api_key)
          case module.handle(tool_name, arguments, frame.assigns) do
            {:reply, response, _state} ->
              {:reply, response, frame}

            other ->
              require Logger
              Logger.error("Unexpected tool response: #{inspect(other)}")

              response =
                Response.tool()
                |> Response.error("Internal error")

              {:reply, response, frame}
          end

        :error ->
          require Logger
          Logger.warning("Unknown tool called: #{tool_name}")

          response =
            Response.tool()
            |> Response.error("Unknown tool: #{tool_name}")

          {:reply, response, frame}
      end
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

  defp register_all_tools(frame) do
    Enum.reduce(@tool_modules, frame, fn module, acc_frame ->
      Enum.reduce(module.tools(), acc_frame, fn tool, inner_frame ->
        Frame.register_tool(inner_frame, tool.name,
          description: tool.description,
          input_schema: tool.input_schema
        )
      end)
    end)
  end
end
