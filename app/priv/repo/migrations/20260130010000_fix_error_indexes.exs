defmodule GI.Repo.Migrations.FixErrorIndexes do
  use Ecto.Migration

  def change do
    # Add composite indexes for common queries
    create index(:errors, [:status, :last_occurrence_at])
    create index(:errors, [:muted, :last_occurrence_at])

    # Composite index for stacktrace search queries
    create index(:stacktrace_lines, [:occurrence_id, :position])
  end
end
