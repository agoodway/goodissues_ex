defmodule GI.Repo.Migrations.CreateStacktraceLines do
  use Ecto.Migration

  def change do
    create table(:stacktrace_lines, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :occurrence_id, references(:occurrences, type: :binary_id, on_delete: :delete_all),
        null: false

      add :position, :integer, null: false
      add :application, :string, size: 255
      add :module, :string, size: 255
      add :function, :string, size: 255
      add :arity, :integer
      add :file, :string, size: 500
      add :line, :integer
    end

    create index(:stacktrace_lines, [:occurrence_id])
    create index(:stacktrace_lines, [:module])
    create index(:stacktrace_lines, [:function])
    create index(:stacktrace_lines, [:file])
  end
end
