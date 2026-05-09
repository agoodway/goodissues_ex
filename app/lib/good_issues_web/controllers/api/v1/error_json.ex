defmodule GIWeb.Api.V1.ErrorJSON do
  @moduledoc """
  JSON rendering for Error resources.
  """

  alias GI.Tracking.{Error, Occurrence, StacktraceLine}

  def index(%{
        errors: errors,
        page: page,
        per_page: per_page,
        total: total,
        total_pages: total_pages
      }) do
    %{
      data: for(error <- errors, do: data(error)),
      meta: %{
        page: page,
        per_page: per_page,
        total: total,
        total_pages: total_pages
      }
    }
  end

  def show(%{error: error}) do
    %{data: data_with_occurrences(error)}
  end

  defp data(%Error{} = error) do
    %{
      id: error.id,
      issue_id: error.issue_id,
      kind: error.kind,
      reason: error.reason,
      source_line: error.source_line,
      source_function: error.source_function,
      status: error.status,
      fingerprint: error.fingerprint,
      last_occurrence_at: error.last_occurrence_at,
      muted: error.muted,
      inserted_at: error.inserted_at,
      updated_at: error.updated_at
    }
  end

  defp data_with_occurrences(%Error{} = error) do
    base = data(error)

    occurrences =
      case error.occurrences do
        %Ecto.Association.NotLoaded{} -> []
        occurrences -> Enum.map(occurrences, &occurrence_data/1)
      end

    occurrence_count = Map.get(error, :occurrence_count, length(occurrences))

    Map.merge(base, %{
      occurrences: occurrences,
      occurrence_count: occurrence_count
    })
  end

  defp occurrence_data(%Occurrence{} = occurrence) do
    %{
      id: occurrence.id,
      reason: occurrence.reason,
      context: occurrence.context,
      breadcrumbs: occurrence.breadcrumbs,
      stacktrace: stacktrace_data(occurrence.stacktrace_lines),
      inserted_at: occurrence.inserted_at
    }
  end

  defp stacktrace_data(%Ecto.Association.NotLoaded{}), do: %{lines: []}

  defp stacktrace_data(lines) when is_list(lines) do
    %{
      lines:
        lines
        |> Enum.sort_by(& &1.position)
        |> Enum.map(&stacktrace_line_data/1)
    }
  end

  defp stacktrace_line_data(%StacktraceLine{} = line) do
    %{
      application: line.application,
      module: line.module,
      function: line.function,
      arity: line.arity,
      file: line.file,
      line: line.line
    }
  end
end
