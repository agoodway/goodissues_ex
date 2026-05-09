defmodule GIWeb.Api.V1.HeartbeatPingController do
  use GIWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GI.Monitoring
  alias GIWeb.Api.V1.Schemas.Heartbeat, as: HBSchemas

  action_fallback GIWeb.FallbackController

  tags(["Heartbeat Pings"])

  @max_payload_bytes 4_096

  operation(:ping,
    summary: "Send a success ping",
    description:
      "Signal that the monitored job completed. No Bearer auth required — the token in the URL authenticates.",
    security: [],
    parameters: [
      project_id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        required: true
      ],
      heartbeat_token: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string},
        required: true
      ]
    ],
    request_body:
      {"Optional JSON payload", "application/json", HBSchemas.PingPayload, required: false},
    responses: [
      no_content: "Ping received",
      not_found: {"Not found", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def ping(conn, %{"project_id" => project_id, "heartbeat_token" => token} = params) do
    with {:ok, payload} <- validate_payload(params),
         %{} = heartbeat <- Monitoring.get_heartbeat_by_token(project_id, token) || :not_found,
         {:ok, _ping} <- Monitoring.receive_ping(heartbeat, :ping, %{payload: payload}) do
      send_resp(conn, :no_content, "")
    else
      :not_found -> {:error, :not_found}
      {:error, _, _} = err -> err
      {:error, reason} -> {:error, reason}
    end
  end

  operation(:start,
    summary: "Send a start ping",
    description: "Signal that the monitored job has started. No Bearer auth required.",
    security: [],
    parameters: [
      project_id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        required: true
      ],
      heartbeat_token: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string},
        required: true
      ]
    ],
    request_body:
      {"Optional JSON payload", "application/json", HBSchemas.PingPayload, required: false},
    responses: [
      no_content: "Start ping received",
      not_found: {"Not found", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def start(conn, %{"project_id" => project_id, "heartbeat_token" => token} = params) do
    with {:ok, payload} <- validate_payload(params),
         %{} = heartbeat <- Monitoring.get_heartbeat_by_token(project_id, token) || :not_found,
         {:ok, _ping} <- Monitoring.receive_ping(heartbeat, :start, %{payload: payload}) do
      send_resp(conn, :no_content, "")
    else
      :not_found -> {:error, :not_found}
      {:error, _, _} = err -> err
      {:error, reason} -> {:error, reason}
    end
  end

  operation(:fail,
    summary: "Send a failure ping",
    description:
      "Signal that the monitored job failed. No Bearer auth required. `exit_code` is a reserved field persisted separately.",
    security: [],
    parameters: [
      project_id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string, format: :uuid},
        required: true
      ],
      heartbeat_token: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string},
        required: true
      ]
    ],
    request_body:
      {"Optional JSON payload with exit_code", "application/json", HBSchemas.PingPayload,
       required: false},
    responses: [
      no_content: "Fail ping received",
      not_found: {"Not found", "application/json", GIWeb.ErrorJSON}
    ]
  )

  def fail(conn, %{"project_id" => project_id, "heartbeat_token" => token} = params) do
    with {:ok, _payload} <- validate_payload(params),
         %{} = heartbeat <- Monitoring.get_heartbeat_by_token(project_id, token) || :not_found do
      {exit_code, payload} = extract_fail_payload(params)

      case validate_exit_code(exit_code) do
        :ok ->
          case Monitoring.receive_ping(heartbeat, :fail, %{
                 payload: payload,
                 exit_code: exit_code
               }) do
            {:ok, _ping} -> send_resp(conn, :no_content, "")
            {:error, reason} -> {:error, reason}
          end

        {:error, _, _} = err ->
          err
      end
    else
      :not_found -> {:error, :not_found}
      {:error, _, _} = err -> err
      {:error, reason} -> {:error, reason}
    end
  end

  # Validates payload size does not exceed 4KB
  defp validate_payload(params) do
    payload = extract_payload(params)

    case payload do
      nil ->
        {:ok, nil}

      p ->
        encoded = Jason.encode!(p)

        if byte_size(encoded) > @max_payload_bytes do
          {:error, :bad_request, "payload exceeds maximum size of #{@max_payload_bytes} bytes"}
        else
          {:ok, p}
        end
    end
  end

  # Extract payload from params, excluding Phoenix router keys
  defp extract_payload(params) do
    params
    |> Map.drop(["project_id", "heartbeat_token", "_format", "action", "controller"])
    |> case do
      empty when map_size(empty) == 0 -> nil
      payload -> payload
    end
  end

  # For /fail, separate exit_code from payload
  defp extract_fail_payload(params) do
    payload = extract_payload(params)

    case payload do
      nil ->
        {nil, nil}

      %{"exit_code" => exit_code} = p ->
        remaining = Map.delete(p, "exit_code")
        remaining = if map_size(remaining) == 0, do: nil, else: remaining
        {exit_code, remaining}

      p ->
        {nil, p}
    end
  end

  defp validate_exit_code(nil), do: :ok

  defp validate_exit_code(code) when is_integer(code) and code >= 0 and code <= 255, do: :ok

  defp validate_exit_code(_code),
    do: {:error, :bad_request, "exit_code must be an integer between 0 and 255"}
end
