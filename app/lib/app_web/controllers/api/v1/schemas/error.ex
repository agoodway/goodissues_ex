defmodule FFWeb.Api.V1.Schemas.Error do
  @moduledoc """
  OpenAPI schemas for Error endpoints.
  """
  alias OpenApiSpex.Schema
  require OpenApiSpex

  defmodule ErrorStatus do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ErrorStatus",
      description: "Status of error",
      type: :string,
      enum: ["resolved", "unresolved"]
    })
  end

  defmodule StacktraceLineSchema do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "StacktraceLineSchema",
      description: "A single line in a stacktrace",
      type: :object,
      properties: %{
        application: %Schema{type: :string, description: "Application name", nullable: true},
        module: %Schema{type: :string, description: "Module name", nullable: true},
        function: %Schema{type: :string, description: "Function name", nullable: true},
        arity: %Schema{type: :integer, description: "Function arity", nullable: true},
        file: %Schema{type: :string, description: "Source file path", nullable: true},
        line: %Schema{type: :integer, description: "Line number", nullable: true}
      },
      example: %{
        "application" => "my_app",
        "module" => "MyApp.SomeModule",
        "function" => "do_something",
        "arity" => 2,
        "file" => "lib/my_app/some_module.ex",
        "line" => 42
      }
    })
  end

  defmodule StacktraceSchema do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "StacktraceSchema",
      description: "Stacktrace containing lines",
      type: :object,
      properties: %{
        lines: %Schema{
          type: :array,
          items: StacktraceLineSchema,
          description: "Stacktrace lines ordered by position"
        }
      },
      required: [:lines],
      example: %{
        "lines" => [
          %{
            "application" => "my_app",
            "module" => "MyApp.SomeModule",
            "function" => "do_something",
            "arity" => 2,
            "file" => "lib/my_app/some_module.ex",
            "line" => 42
          }
        ]
      }
    })
  end

  defmodule OccurrenceSchema do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "OccurrenceSchema",
      description: "An error occurrence with context and stacktrace",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, description: "Occurrence ID"},
        reason: %Schema{type: :string, description: "Error reason/message", nullable: true},
        context: %Schema{
          type: :object,
          description: "Contextual data captured at time of error",
          additionalProperties: true
        },
        breadcrumbs: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "Breadcrumb trail leading to error"
        },
        stacktrace: StacktraceSchema,
        inserted_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When the occurrence was recorded"
        }
      },
      required: [:id, :inserted_at],
      example: %{
        "id" => "550e8400-e29b-41d4-a716-446655440003",
        "reason" => "connection timeout",
        "context" => %{
          "user_id" => 12345,
          "request_path" => "/api/v1/users"
        },
        "breadcrumbs" => ["Started request", "Authenticated user", "Querying database"],
        "stacktrace" => %{
          "lines" => [
            %{
              "module" => "MyApp.Repo",
              "function" => "query",
              "arity" => 2,
              "file" => "lib/my_app/repo.ex",
              "line" => 15
            }
          ]
        },
        "inserted_at" => "2024-01-15T10:30:00Z"
      }
    })
  end

  defmodule ErrorSchema do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ErrorSchema",
      description: "An error resource",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, description: "Error ID"},
        issue_id: %Schema{type: :string, format: :uuid, description: "Associated issue ID"},
        kind: %Schema{type: :string, description: "Error type/exception name"},
        reason: %Schema{type: :string, description: "Error message"},
        source_line: %Schema{type: :string, description: "Source line where error occurred"},
        source_function: %Schema{
          type: :string,
          description: "Function where error occurred"
        },
        status: ErrorStatus,
        fingerprint: %Schema{
          type: :string,
          description: "64-character fingerprint for deduplication"
        },
        muted: %Schema{type: :boolean, description: "Whether notifications are muted"},
        last_occurrence_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When the error last occurred"
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
        :issue_id,
        :kind,
        :reason,
        :status,
        :fingerprint,
        :muted,
        :last_occurrence_at,
        :inserted_at,
        :updated_at
      ],
      example: %{
        "id" => "550e8400-e29b-41d4-a716-446655440010",
        "issue_id" => "550e8400-e29b-41d4-a716-446655440001",
        "kind" => "Elixir.DBConnection.ConnectionError",
        "reason" => "connection not available and request was dropped from queue after 2000ms",
        "source_line" => "lib/my_app/repo.ex:42",
        "source_function" => "MyApp.Repo.query/2",
        "status" => "unresolved",
        "fingerprint" => "a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd",
        "muted" => false,
        "last_occurrence_at" => "2024-01-15T10:30:00Z",
        "inserted_at" => "2024-01-15T10:30:00Z",
        "updated_at" => "2024-01-15T10:30:00Z"
      }
    })
  end

  defmodule ErrorWithOccurrencesSchema do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ErrorWithOccurrencesSchema",
      description: "An error resource with occurrences",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, description: "Error ID"},
        issue_id: %Schema{type: :string, format: :uuid, description: "Associated issue ID"},
        kind: %Schema{type: :string, description: "Error type/exception name"},
        reason: %Schema{type: :string, description: "Error message"},
        source_line: %Schema{type: :string, description: "Source line where error occurred"},
        source_function: %Schema{
          type: :string,
          description: "Function where error occurred"
        },
        status: ErrorStatus,
        fingerprint: %Schema{
          type: :string,
          description: "64-character fingerprint for deduplication"
        },
        muted: %Schema{type: :boolean, description: "Whether notifications are muted"},
        last_occurrence_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When the error last occurred"
        },
        occurrence_count: %Schema{
          type: :integer,
          description: "Total number of occurrences"
        },
        occurrences: %Schema{
          type: :array,
          items: OccurrenceSchema,
          description: "List of occurrences (paginated)"
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
        :issue_id,
        :kind,
        :reason,
        :status,
        :fingerprint,
        :muted,
        :last_occurrence_at,
        :occurrence_count,
        :occurrences,
        :inserted_at,
        :updated_at
      ],
      example: %{
        "id" => "550e8400-e29b-41d4-a716-446655440010",
        "issue_id" => "550e8400-e29b-41d4-a716-446655440001",
        "kind" => "Elixir.DBConnection.ConnectionError",
        "reason" => "connection not available and request was dropped from queue after 2000ms",
        "source_line" => "lib/my_app/repo.ex:42",
        "source_function" => "MyApp.Repo.query/2",
        "status" => "unresolved",
        "fingerprint" => "a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd",
        "muted" => false,
        "last_occurrence_at" => "2024-01-15T10:30:00Z",
        "occurrence_count" => 5,
        "occurrences" => [
          %{
            "id" => "550e8400-e29b-41d4-a716-446655440003",
            "reason" => "connection timeout",
            "context" => %{"user_id" => 12345},
            "breadcrumbs" => [],
            "stacktrace" => %{"lines" => []},
            "inserted_at" => "2024-01-15T10:30:00Z"
          }
        ],
        "inserted_at" => "2024-01-15T10:30:00Z",
        "updated_at" => "2024-01-15T10:30:00Z"
      }
    })
  end

  defmodule ErrorResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ErrorResponse",
      description: "Single error response wrapper",
      type: :object,
      properties: %{
        data: ErrorWithOccurrencesSchema
      },
      required: [:data]
    })
  end

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

  defmodule ErrorListResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ErrorListResponse",
      description: "Paginated list of errors",
      type: :object,
      properties: %{
        data: %Schema{
          type: :array,
          items: ErrorSchema,
          description: "List of errors"
        },
        meta: PaginationMeta
      },
      required: [:data, :meta],
      example: %{
        "data" => [
          %{
            "id" => "550e8400-e29b-41d4-a716-446655440010",
            "issue_id" => "550e8400-e29b-41d4-a716-446655440001",
            "kind" => "Elixir.RuntimeError",
            "reason" => "something went wrong",
            "source_line" => "-",
            "source_function" => "-",
            "status" => "unresolved",
            "fingerprint" => "a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd",
            "muted" => false,
            "last_occurrence_at" => "2024-01-15T10:30:00Z",
            "inserted_at" => "2024-01-15T10:30:00Z",
            "updated_at" => "2024-01-15T10:30:00Z"
          }
        ],
        "meta" => %{
          "page" => 1,
          "per_page" => 20,
          "total" => 1,
          "total_pages" => 1
        }
      }
    })
  end

  defmodule ErrorReportRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ErrorReportRequest",
      description: "Request body for reporting an error",
      type: :object,
      properties: %{
        project_id: %Schema{
          type: :string,
          format: :uuid,
          description: "Project ID where error occurred"
        },
        kind: %Schema{type: :string, description: "Error type/exception name", maxLength: 255},
        reason: %Schema{type: :string, description: "Error message"},
        fingerprint: %Schema{
          type: :string,
          description: "64-character fingerprint for deduplication",
          minLength: 64,
          maxLength: 64
        },
        source_line: %Schema{
          type: :string,
          description: "Source line where error occurred",
          nullable: true
        },
        source_function: %Schema{
          type: :string,
          description: "Function where error occurred",
          nullable: true
        },
        context: %Schema{
          type: :object,
          description: "Contextual data captured at time of error",
          additionalProperties: true,
          nullable: true
        },
        breadcrumbs: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "Breadcrumb trail leading to error",
          nullable: true
        },
        stacktrace: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              application: %Schema{type: :string, nullable: true},
              module: %Schema{type: :string, nullable: true},
              function: %Schema{type: :string, nullable: true},
              arity: %Schema{type: :integer, nullable: true},
              file: %Schema{type: :string, nullable: true},
              line: %Schema{type: :integer, nullable: true}
            }
          },
          description: "Stacktrace lines"
        }
      },
      required: [:project_id, :kind, :reason, :fingerprint],
      example: %{
        "project_id" => "550e8400-e29b-41d4-a716-446655440000",
        "kind" => "Elixir.DBConnection.ConnectionError",
        "reason" => "connection not available and request was dropped from queue after 2000ms",
        "fingerprint" => "a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd",
        "context" => %{
          "user_id" => 12345,
          "request_path" => "/api/v1/users"
        },
        "stacktrace" => [
          %{
            "module" => "MyApp.Repo",
            "function" => "query",
            "arity" => 2,
            "file" => "lib/my_app/repo.ex",
            "line" => 15
          }
        ]
      }
    })
  end

  defmodule ErrorUpdateRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ErrorUpdateRequest",
      description: "Request body for updating an error",
      type: :object,
      properties: %{
        status: ErrorStatus,
        muted: %Schema{type: :boolean, description: "Whether to mute notifications"}
      },
      example: %{
        "status" => "resolved",
        "muted" => true
      }
    })
  end
end
