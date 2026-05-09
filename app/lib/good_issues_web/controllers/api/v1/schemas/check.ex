defmodule GIWeb.Api.V1.Schemas.Check do
  @moduledoc """
  OpenAPI schemas for Check and CheckResult endpoints.
  """
  alias OpenApiSpex.Schema
  require OpenApiSpex

  defmodule CheckMethod do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "CheckMethod",
      type: :string,
      enum: ["get", "head", "post"]
    })
  end

  defmodule CheckStatus do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "CheckStatus",
      type: :string,
      enum: ["unknown", "up", "down"]
    })
  end

  defmodule CheckRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "CheckRequest",
      description: "Request body for creating a check",
      type: :object,
      properties: %{
        name: %Schema{type: :string, maxLength: 255},
        url: %Schema{type: :string, maxLength: 2048},
        method: CheckMethod,
        interval_seconds: %Schema{type: :integer, minimum: 30, maximum: 3600},
        expected_status: %Schema{type: :integer, minimum: 100, maximum: 599},
        keyword: %Schema{type: :string, maxLength: 255, nullable: true},
        keyword_absence: %Schema{type: :boolean},
        paused: %Schema{type: :boolean},
        failure_threshold: %Schema{type: :integer, minimum: 1},
        reopen_window_hours: %Schema{type: :integer, minimum: 1}
      },
      required: [:name, :url],
      example: %{
        "name" => "API Health",
        "url" => "https://api.example.com/health",
        "method" => "get",
        "interval_seconds" => 300,
        "expected_status" => 200
      }
    })
  end

  defmodule CheckUpdateRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "CheckUpdateRequest",
      description: "Request body for updating a check; all fields optional.",
      type: :object,
      properties: %{
        name: %Schema{type: :string, maxLength: 255},
        url: %Schema{type: :string, maxLength: 2048},
        method: CheckMethod,
        interval_seconds: %Schema{type: :integer, minimum: 30, maximum: 3600},
        expected_status: %Schema{type: :integer, minimum: 100, maximum: 599},
        keyword: %Schema{type: :string, maxLength: 255, nullable: true},
        keyword_absence: %Schema{type: :boolean},
        paused: %Schema{type: :boolean},
        failure_threshold: %Schema{type: :integer, minimum: 1},
        reopen_window_hours: %Schema{type: :integer, minimum: 1}
      },
      example: %{
        "interval_seconds" => 60,
        "paused" => false
      }
    })
  end

  defmodule CheckResource do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Check",
      description: "An uptime check resource",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        name: %Schema{type: :string},
        url: %Schema{type: :string},
        method: CheckMethod,
        interval_seconds: %Schema{type: :integer},
        expected_status: %Schema{type: :integer},
        keyword: %Schema{type: :string, nullable: true},
        keyword_absence: %Schema{type: :boolean},
        paused: %Schema{type: :boolean},
        status: CheckStatus,
        failure_threshold: %Schema{type: :integer},
        reopen_window_hours: %Schema{type: :integer},
        consecutive_failures: %Schema{type: :integer},
        last_checked_at: %Schema{type: :string, format: :"date-time", nullable: true},
        current_issue_id: %Schema{type: :string, format: :uuid, nullable: true},
        project_id: %Schema{type: :string, format: :uuid},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :name, :url, :method, :status, :project_id, :inserted_at, :updated_at]
    })
  end

  defmodule CheckResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "CheckResponse",
      type: :object,
      properties: %{data: CheckResource},
      required: [:data]
    })
  end

  defmodule CheckListResponse do
    @moduledoc false
    alias GIWeb.Api.V1.Schemas.Pagination
    OpenApiSpex.schema(Pagination.paginated_list("Check", CheckResource))
  end

  defmodule CheckResultResource do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "CheckResult",
      description: "A single check execution result",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        status: %Schema{type: :string, enum: ["up", "down"]},
        status_code: %Schema{type: :integer, nullable: true},
        response_ms: %Schema{type: :integer, nullable: true},
        error: %Schema{type: :string, nullable: true},
        checked_at: %Schema{type: :string, format: :"date-time"},
        check_id: %Schema{type: :string, format: :uuid},
        issue_id: %Schema{type: :string, format: :uuid, nullable: true}
      },
      required: [:id, :status, :checked_at, :check_id]
    })
  end

  defmodule CheckResultListResponse do
    @moduledoc false
    alias GIWeb.Api.V1.Schemas.Pagination
    OpenApiSpex.schema(Pagination.paginated_list("CheckResult", CheckResultResource))
  end
end
