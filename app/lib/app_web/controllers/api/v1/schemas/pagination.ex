defmodule FFWeb.Api.V1.Schemas.Pagination do
  @moduledoc """
  Shared OpenAPI schemas for pagination.
  """
  alias OpenApiSpex.Schema
  require OpenApiSpex

  defmodule PaginationMeta do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "PaginationMeta",
      description: "Pagination metadata",
      type: :object,
      properties: %{
        page: %Schema{type: :integer, description: "Current page number"},
        per_page: %Schema{type: :integer, description: "Items per page"},
        total: %Schema{type: :integer, description: "Total number of items"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"}
      },
      required: [:page, :per_page, :total, :total_pages],
      example: %{
        "page" => 1,
        "per_page" => 20,
        "total" => 42,
        "total_pages" => 3
      }
    })
  end

  @doc """
  Generates a paginated list response schema map for use with `OpenApiSpex.schema/1`.

  ## Examples

      defmodule ProjectListResponse do
        OpenApiSpex.schema(Pagination.paginated_list("Project", ProjectResponse))
      end

  """
  def paginated_list(title, item_schema) do
    %{
      title: "#{title}ListResponse",
      description: "Paginated list of #{String.downcase(title)}s",
      type: :object,
      properties: %{
        data: %Schema{
          type: :array,
          items: item_schema,
          description: "List of #{String.downcase(title)}s"
        },
        meta: PaginationMeta
      },
      required: [:data, :meta]
    }
  end
end
