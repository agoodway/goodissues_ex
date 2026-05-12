defmodule GIWeb.Api.V1.IncidentJSON do
  @moduledoc """
  JSON rendering for Incident resources.
  """

  alias GI.Tracking.{Incident, IncidentOccurrence}

  def index(%{
        incidents: incidents,
        page: page,
        per_page: per_page,
        total: total,
        total_pages: total_pages
      }) do
    %{
      data: for(incident <- incidents, do: data(incident)),
      meta: %{
        page: page,
        per_page: per_page,
        total: total,
        total_pages: total_pages
      }
    }
  end

  def show(%{incident: incident}) do
    %{data: data_with_occurrences(incident)}
  end

  defp data(%Incident{} = incident) do
    %{
      id: incident.id,
      issue_id: incident.issue_id,
      fingerprint: incident.fingerprint,
      title: incident.title,
      severity: incident.severity,
      source: incident.source,
      status: incident.status,
      muted: incident.muted,
      last_occurrence_at: incident.last_occurrence_at,
      metadata: incident.metadata,
      inserted_at: incident.inserted_at,
      updated_at: incident.updated_at
    }
  end

  defp data_with_occurrences(%Incident{} = incident) do
    base = data(incident)

    occurrences =
      case incident.incident_occurrences do
        %Ecto.Association.NotLoaded{} -> []
        occurrences -> Enum.map(occurrences, &occurrence_data/1)
      end

    occurrence_count = Map.get(incident, :occurrence_count, length(occurrences))

    Map.merge(base, %{
      occurrences: occurrences,
      occurrence_count: occurrence_count
    })
  end

  defp occurrence_data(%IncidentOccurrence{} = occurrence) do
    %{
      id: occurrence.id,
      context: occurrence.context,
      inserted_at: occurrence.inserted_at
    }
  end
end
