defmodule FFWeb.Api.V1.Schemas.Project do
  @moduledoc """
  OpenAPI schemas for Project endpoints.
  """
  alias OpenApiSpex.Schema
  require OpenApiSpex

  defmodule ProjectRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ProjectRequest",
      description: "Request body for creating or updating a project",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Project name", maxLength: 255},
        description: %Schema{type: :string, description: "Project description", nullable: true}
      },
      required: [:name],
      example: %{
        "name" => "My Project",
        "description" => "A description of the project"
      }
    })
  end

  defmodule ProjectResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ProjectResponse",
      description: "A project resource",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, description: "Project ID"},
        name: %Schema{type: :string, description: "Project name"},
        description: %Schema{type: :string, description: "Project description", nullable: true},
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
      required: [:id, :name, :inserted_at, :updated_at],
      example: %{
        "id" => "550e8400-e29b-41d4-a716-446655440000",
        "name" => "My Project",
        "description" => "A description of the project",
        "inserted_at" => "2024-01-15T10:30:00Z",
        "updated_at" => "2024-01-15T10:30:00Z"
      }
    })
  end

  defmodule ProjectListResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ProjectListResponse",
      description: "List of projects",
      type: :object,
      properties: %{
        data: %Schema{
          type: :array,
          items: ProjectResponse,
          description: "List of projects"
        }
      },
      required: [:data],
      example: %{
        "data" => [
          %{
            "id" => "550e8400-e29b-41d4-a716-446655440000",
            "name" => "My Project",
            "description" => "A description of the project",
            "inserted_at" => "2024-01-15T10:30:00Z",
            "updated_at" => "2024-01-15T10:30:00Z"
          }
        ]
      }
    })
  end
end
