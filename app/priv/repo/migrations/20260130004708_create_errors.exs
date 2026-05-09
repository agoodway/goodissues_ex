defmodule GI.Repo.Migrations.CreateErrors do
  use Ecto.Migration

  def change do
    create table(:errors, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :issue_id, references(:issues, type: :binary_id, on_delete: :delete_all), null: false

      add :kind, :string, null: false, size: 255
      add :reason, :text, null: false
      add :source_line, :string, size: 255, default: "-"
      add :source_function, :string, size: 255, default: "-"
      add :status, :string, null: false, default: "unresolved", size: 20
      add :fingerprint, :string, null: false, size: 64
      add :last_occurrence_at, :utc_datetime, null: false
      add :muted, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:errors, [:issue_id])
    create index(:errors, [:fingerprint])
    create index(:errors, [:status])
    create index(:errors, [:last_occurrence_at])
  end
end
