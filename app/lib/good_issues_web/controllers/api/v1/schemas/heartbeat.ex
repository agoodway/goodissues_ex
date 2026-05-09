defmodule FFWeb.Api.V1.Schemas.Heartbeat do
  @moduledoc """
  OpenAPI schemas for Heartbeat, HeartbeatPing, and AlertRule endpoints.
  """
  alias OpenApiSpex.Schema
  require OpenApiSpex

  defmodule HeartbeatStatus do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "HeartbeatStatus",
      type: :string,
      enum: ["unknown", "up", "down"]
    })
  end

  defmodule AlertRule do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "AlertRule",
      description: "A single alert rule evaluated against ping payloads",
      type: :object,
      properties: %{
        field: %Schema{type: :string, description: "Flat top-level payload field name"},
        op: %Schema{
          type: :string,
          enum: ["eq", "neq", "gt", "gte", "lt", "lte"],
          description: "Comparison operator"
        },
        value: %Schema{
          description: "JSON scalar value to compare against",
          oneOf: [
            %Schema{type: :string},
            %Schema{type: :number},
            %Schema{type: :boolean},
            %Schema{type: :string, nullable: true}
          ]
        }
      },
      required: [:field, :op, :value]
    })
  end

  defmodule HeartbeatRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "HeartbeatRequest",
      description: "Request body for creating a heartbeat",
      type: :object,
      properties: %{
        name: %Schema{type: :string, maxLength: 255},
        interval_seconds: %Schema{type: :integer, minimum: 30, maximum: 86_400},
        grace_seconds: %Schema{type: :integer, minimum: 0, maximum: 86_400},
        failure_threshold: %Schema{type: :integer, minimum: 1},
        reopen_window_hours: %Schema{type: :integer, minimum: 1},
        paused: %Schema{type: :boolean},
        alert_rules: %Schema{type: :array, items: AlertRule}
      },
      required: [:name],
      example: %{
        "name" => "nightly-backup",
        "interval_seconds" => 86_400,
        "grace_seconds" => 1800
      }
    })
  end

  defmodule HeartbeatUpdateRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "HeartbeatUpdateRequest",
      description: "Request body for updating a heartbeat; all fields optional.",
      type: :object,
      properties: %{
        name: %Schema{type: :string, maxLength: 255},
        interval_seconds: %Schema{type: :integer, minimum: 30, maximum: 86_400},
        grace_seconds: %Schema{type: :integer, minimum: 0, maximum: 86_400},
        failure_threshold: %Schema{type: :integer, minimum: 1},
        reopen_window_hours: %Schema{type: :integer, minimum: 1},
        paused: %Schema{type: :boolean},
        alert_rules: %Schema{type: :array, items: AlertRule}
      },
      example: %{
        "interval_seconds" => 3600,
        "paused" => false
      }
    })
  end

  defmodule HeartbeatResource do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Heartbeat",
      description: "A heartbeat monitor resource (token redacted on read)",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        name: %Schema{type: :string},
        interval_seconds: %Schema{type: :integer},
        grace_seconds: %Schema{type: :integer},
        failure_threshold: %Schema{type: :integer},
        reopen_window_hours: %Schema{type: :integer},
        paused: %Schema{type: :boolean},
        status: HeartbeatStatus,
        consecutive_failures: %Schema{type: :integer},
        last_ping_at: %Schema{type: :string, format: :"date-time", nullable: true},
        next_due_at: %Schema{type: :string, format: :"date-time", nullable: true},
        alert_rules: %Schema{type: :array, items: AlertRule},
        current_issue_id: %Schema{type: :string, format: :uuid, nullable: true},
        project_id: %Schema{type: :string, format: :uuid},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :name, :status, :project_id, :inserted_at, :updated_at]
    })
  end

  defmodule HeartbeatCreateResource do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "HeartbeatCreateResponse",
      description: "Heartbeat resource returned on create (includes full ping URL)",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        name: %Schema{type: :string},
        ping_token: %Schema{type: :string, description: "Full 42-character ping token"},
        ping_url: %Schema{type: :string, description: "Full ping URL for provisioning"},
        interval_seconds: %Schema{type: :integer},
        grace_seconds: %Schema{type: :integer},
        failure_threshold: %Schema{type: :integer},
        reopen_window_hours: %Schema{type: :integer},
        paused: %Schema{type: :boolean},
        status: HeartbeatStatus,
        consecutive_failures: %Schema{type: :integer},
        last_ping_at: %Schema{type: :string, format: :"date-time", nullable: true},
        next_due_at: %Schema{type: :string, format: :"date-time", nullable: true},
        alert_rules: %Schema{type: :array, items: AlertRule},
        current_issue_id: %Schema{type: :string, format: :uuid, nullable: true},
        project_id: %Schema{type: :string, format: :uuid},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [
        :id,
        :name,
        :ping_token,
        :ping_url,
        :status,
        :project_id,
        :inserted_at,
        :updated_at
      ]
    })
  end

  defmodule HeartbeatResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "HeartbeatResponse",
      type: :object,
      properties: %{data: HeartbeatResource},
      required: [:data]
    })
  end

  defmodule HeartbeatCreateResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "HeartbeatCreateResponseEnvelope",
      type: :object,
      properties: %{data: HeartbeatCreateResource},
      required: [:data]
    })
  end

  defmodule HeartbeatListResponse do
    @moduledoc false
    alias FFWeb.Api.V1.Schemas.Pagination
    OpenApiSpex.schema(Pagination.paginated_list("Heartbeat", HeartbeatResource))
  end

  defmodule PingKind do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "PingKind",
      type: :string,
      enum: ["ping", "start", "fail"]
    })
  end

  defmodule HeartbeatPingResource do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "HeartbeatPing",
      description: "A heartbeat ping record",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        kind: PingKind,
        exit_code: %Schema{type: :integer, nullable: true},
        payload: %Schema{type: :object, nullable: true},
        duration_ms: %Schema{type: :integer, nullable: true},
        pinged_at: %Schema{type: :string, format: :"date-time"},
        heartbeat_id: %Schema{type: :string, format: :uuid},
        issue_id: %Schema{type: :string, format: :uuid, nullable: true}
      },
      required: [:id, :kind, :pinged_at, :heartbeat_id]
    })
  end

  defmodule HeartbeatPingListResponse do
    @moduledoc false
    alias FFWeb.Api.V1.Schemas.Pagination
    OpenApiSpex.schema(Pagination.paginated_list("HeartbeatPing", HeartbeatPingResource))
  end

  defmodule PingPayload do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "PingPayload",
      description: "Optional JSON payload for ping endpoints",
      type: :object,
      properties: %{
        exit_code: %Schema{type: :integer, description: "Reserved field for /ping/fail"}
      },
      additionalProperties: true
    })
  end
end
