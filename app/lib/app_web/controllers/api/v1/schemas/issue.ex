defmodule FFWeb.Api.V1.Schemas.Issue do
  @moduledoc """
  OpenAPI schemas for Issue endpoints.
  """
  alias OpenApiSpex.Schema
  require OpenApiSpex

  defmodule IssueType do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "IssueType",
      description: "Type of issue",
      type: :string,
      enum: ["bug", "feature_request"]
    })
  end

  defmodule IssueStatus do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "IssueStatus",
      description: "Status of issue",
      type: :string,
      enum: ["new", "in_progress", "archived"]
    })
  end

  defmodule IssuePriority do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "IssuePriority",
      description: "Priority of issue",
      type: :string,
      enum: ["low", "medium", "high", "critical"]
    })
  end

  defmodule IssueRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "IssueRequest",
      description: "Request body for creating or updating an issue",
      type: :object,
      properties: %{
        title: %Schema{type: :string, description: "Issue title", maxLength: 255},
        description: %Schema{type: :string, description: "Issue description", nullable: true},
        type: IssueType,
        status: IssueStatus,
        priority: IssuePriority,
        project_id: %Schema{
          type: :string,
          format: :uuid,
          description: "Project ID (required for creation)"
        },
        submitter_email: %Schema{
          type: :string,
          description: "Optional submitter email",
          maxLength: 255,
          nullable: true
        }
      },
      required: [:title, :type, :project_id],
      example: %{
        "title" => "Login button not working",
        "description" => "When clicking the login button, nothing happens",
        "type" => "bug",
        "status" => "new",
        "priority" => "high",
        "project_id" => "550e8400-e29b-41d4-a716-446655440000",
        "submitter_email" => "user@example.com"
      }
    })
  end

  defmodule IssueUpdateRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "IssueUpdateRequest",
      description: "Request body for updating an issue",
      type: :object,
      properties: %{
        title: %Schema{type: :string, description: "Issue title", maxLength: 255},
        description: %Schema{type: :string, description: "Issue description", nullable: true},
        type: IssueType,
        status: IssueStatus,
        priority: IssuePriority,
        submitter_email: %Schema{
          type: :string,
          description: "Optional submitter email",
          maxLength: 255,
          nullable: true
        }
      },
      example: %{
        "title" => "Login button not working",
        "status" => "in_progress",
        "priority" => "critical"
      }
    })
  end

  defmodule IssueSchema do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "IssueSchema",
      description: "An issue resource",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, description: "Issue ID"},
        title: %Schema{type: :string, description: "Issue title"},
        description: %Schema{type: :string, description: "Issue description", nullable: true},
        type: IssueType,
        status: IssueStatus,
        priority: IssuePriority,
        project_id: %Schema{type: :string, format: :uuid, description: "Project ID"},
        submitter_id: %Schema{type: :string, format: :uuid, description: "Submitter user ID"},
        submitter_email: %Schema{
          type: :string,
          description: "Submitter email",
          nullable: true
        },
        archived_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "Archive timestamp",
          nullable: true
        },
        inserted_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "Creation timestamp"
        },
        updated_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "Last update timestamp"
        }
      },
      required: [
        :id,
        :title,
        :type,
        :status,
        :priority,
        :project_id,
        :submitter_id,
        :inserted_at,
        :updated_at
      ],
      example: %{
        "id" => "550e8400-e29b-41d4-a716-446655440001",
        "title" => "Login button not working",
        "description" => "When clicking the login button, nothing happens",
        "type" => "bug",
        "status" => "new",
        "priority" => "high",
        "project_id" => "550e8400-e29b-41d4-a716-446655440000",
        "submitter_id" => "550e8400-e29b-41d4-a716-446655440002",
        "submitter_email" => "user@example.com",
        "archived_at" => nil,
        "inserted_at" => "2024-01-15T10:30:00Z",
        "updated_at" => "2024-01-15T10:30:00Z"
      }
    })
  end

  defmodule IssueResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "IssueResponse",
      description: "Single issue response wrapper",
      type: :object,
      properties: %{
        data: IssueSchema
      },
      required: [:data],
      example: %{
        "data" => %{
          "id" => "550e8400-e29b-41d4-a716-446655440001",
          "title" => "Login button not working",
          "description" => "When clicking the login button, nothing happens",
          "type" => "bug",
          "status" => "new",
          "priority" => "high",
          "project_id" => "550e8400-e29b-41d4-a716-446655440000",
          "submitter_id" => "550e8400-e29b-41d4-a716-446655440002",
          "submitter_email" => "user@example.com",
          "archived_at" => nil,
          "inserted_at" => "2024-01-15T10:30:00Z",
          "updated_at" => "2024-01-15T10:30:00Z"
        }
      }
    })
  end

  defmodule IssueListResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "IssueListResponse",
      description: "List of issues",
      type: :object,
      properties: %{
        data: %Schema{
          type: :array,
          items: IssueSchema,
          description: "List of issues"
        }
      },
      required: [:data],
      example: %{
        "data" => [
          %{
            "id" => "550e8400-e29b-41d4-a716-446655440001",
            "title" => "Login button not working",
            "description" => "When clicking the login button, nothing happens",
            "type" => "bug",
            "status" => "new",
            "priority" => "high",
            "project_id" => "550e8400-e29b-41d4-a716-446655440000",
            "submitter_id" => "550e8400-e29b-41d4-a716-446655440002",
            "submitter_email" => nil,
            "archived_at" => nil,
            "inserted_at" => "2024-01-15T10:30:00Z",
            "updated_at" => "2024-01-15T10:30:00Z"
          }
        ]
      }
    })
  end

  defmodule IssueFilterParams do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "IssueFilterParams",
      description: "Query parameters for filtering issues",
      type: :object,
      properties: %{
        project_id: %Schema{type: :string, format: :uuid, description: "Filter by project ID"},
        status: IssueStatus,
        type: IssueType
      }
    })
  end
end
