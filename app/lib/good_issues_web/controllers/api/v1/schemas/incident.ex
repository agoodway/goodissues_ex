defmodule GIWeb.Api.V1.Schemas.Incident do
  @moduledoc """
  OpenAPI schemas for Incident endpoints.
  """
  alias OpenApiSpex.Schema
  require OpenApiSpex

  defmodule IncidentStatus do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "IncidentStatus",
      description: "Status of incident",
      type: :string,
      enum: ["resolved", "unresolved"]
    })
  end

  defmodule IncidentSeverity do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "IncidentSeverity",
      description: "Severity of incident",
      type: :string,
      enum: ["info", "warning", "critical"]
    })
  end

  defmodule IncidentOccurrenceSchema do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "IncidentOccurrenceSchema",
      description: "An incident occurrence with context",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, description: "Occurrence ID"},
        context: %Schema{
          type: :object,
          description: "Contextual data captured at time of incident",
          additionalProperties: true
        },
        inserted_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When the occurrence was recorded"
        }
      },
      required: [:id, :inserted_at],
      example: %{
        "id" => "550e8400-e29b-41d4-a716-446655440003",
        "context" => %{
          "service" => "api-gateway",
          "region" => "us-east-1"
        },
        "inserted_at" => "2024-01-15T10:30:00Z"
      }
    })
  end

  defmodule IncidentSchema do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "IncidentSchema",
      description: "An incident resource",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, description: "Incident ID"},
        issue_id: %Schema{type: :string, format: :uuid, description: "Associated issue ID"},
        fingerprint: %Schema{
          type: :string,
          description: "Fingerprint for deduplication (max 255 chars)"
        },
        title: %Schema{type: :string, description: "Incident title"},
        severity: IncidentSeverity,
        source: %Schema{type: :string, description: "Source of the incident"},
        status: IncidentStatus,
        muted: %Schema{type: :boolean, description: "Whether notifications are muted"},
        last_occurrence_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When the incident last occurred"
        },
        metadata: %Schema{
          type: :object,
          description: "Additional metadata",
          additionalProperties: true
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
        :fingerprint,
        :title,
        :severity,
        :source,
        :status,
        :muted,
        :last_occurrence_at,
        :inserted_at,
        :updated_at
      ],
      example: %{
        "id" => "550e8400-e29b-41d4-a716-446655440010",
        "issue_id" => "550e8400-e29b-41d4-a716-446655440001",
        "fingerprint" => "service_api-gateway_timeout",
        "title" => "API Gateway Timeout",
        "severity" => "critical",
        "source" => "api-gateway",
        "status" => "unresolved",
        "muted" => false,
        "last_occurrence_at" => "2024-01-15T10:30:00Z",
        "metadata" => %{"region" => "us-east-1"},
        "inserted_at" => "2024-01-15T10:30:00Z",
        "updated_at" => "2024-01-15T10:30:00Z"
      }
    })
  end

  defmodule IncidentWithOccurrencesSchema do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "IncidentWithOccurrencesSchema",
      description: "An incident resource with occurrences",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, description: "Incident ID"},
        issue_id: %Schema{type: :string, format: :uuid, description: "Associated issue ID"},
        fingerprint: %Schema{
          type: :string,
          description: "Fingerprint for deduplication"
        },
        title: %Schema{type: :string, description: "Incident title"},
        severity: IncidentSeverity,
        source: %Schema{type: :string, description: "Source of the incident"},
        status: IncidentStatus,
        muted: %Schema{type: :boolean, description: "Whether notifications are muted"},
        last_occurrence_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When the incident last occurred"
        },
        metadata: %Schema{
          type: :object,
          description: "Additional metadata",
          additionalProperties: true
        },
        occurrence_count: %Schema{
          type: :integer,
          description: "Total number of occurrences"
        },
        occurrences: %Schema{
          type: :array,
          items: IncidentOccurrenceSchema,
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
        :fingerprint,
        :title,
        :severity,
        :source,
        :status,
        :muted,
        :last_occurrence_at,
        :occurrence_count,
        :occurrences,
        :inserted_at,
        :updated_at
      ]
    })
  end

  defmodule IncidentResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "IncidentResponse",
      description: "Single incident response wrapper",
      type: :object,
      properties: %{
        data: IncidentWithOccurrencesSchema
      },
      required: [:data]
    })
  end

  defmodule IncidentListResponse do
    @moduledoc false
    alias GIWeb.Api.V1.Schemas.Pagination

    OpenApiSpex.schema(
      Map.merge(
        Pagination.paginated_list("Incident", IncidentSchema),
        %{
          example: %{
            "data" => [
              %{
                "id" => "550e8400-e29b-41d4-a716-446655440010",
                "issue_id" => "550e8400-e29b-41d4-a716-446655440001",
                "fingerprint" => "service_api-gateway_timeout",
                "title" => "API Gateway Timeout",
                "severity" => "critical",
                "source" => "api-gateway",
                "status" => "unresolved",
                "muted" => false,
                "last_occurrence_at" => "2024-01-15T10:30:00Z",
                "metadata" => %{},
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
        }
      )
    )
  end

  defmodule IncidentReportRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "IncidentReportRequest",
      description: "Request body for reporting an incident",
      type: :object,
      properties: %{
        project_id: %Schema{
          type: :string,
          format: :uuid,
          description: "Project ID where incident occurred"
        },
        fingerprint: %Schema{
          type: :string,
          description: "Fingerprint for deduplication (max 255 chars)",
          maxLength: 255
        },
        title: %Schema{type: :string, description: "Incident title", maxLength: 255},
        severity: IncidentSeverity,
        source: %Schema{type: :string, description: "Source of the incident", maxLength: 255},
        metadata: %Schema{
          type: :object,
          description: "Additional metadata",
          additionalProperties: true,
          nullable: true
        },
        context: %Schema{
          type: :object,
          description: "Contextual data for this occurrence",
          additionalProperties: true,
          nullable: true
        },
        reopen_window_hours: %Schema{
          type: :integer,
          description: "Hours within which a resolved incident can be reopened (default: 24)",
          nullable: true
        }
      },
      required: [:project_id, :fingerprint, :title, :severity, :source],
      example: %{
        "project_id" => "550e8400-e29b-41d4-a716-446655440000",
        "fingerprint" => "service_api-gateway_timeout",
        "title" => "API Gateway Timeout",
        "severity" => "critical",
        "source" => "api-gateway",
        "metadata" => %{"region" => "us-east-1"},
        "context" => %{"request_id" => "abc123"}
      }
    })
  end

  defmodule IncidentUpdateRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "IncidentUpdateRequest",
      description: "Request body for updating an incident (muted only)",
      type: :object,
      properties: %{
        muted: %Schema{type: :boolean, description: "Whether to mute notifications"}
      },
      example: %{
        "muted" => true
      }
    })
  end
end
