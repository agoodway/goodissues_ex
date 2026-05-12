defmodule GI.Repo.Migrations.CreateIncidents do
  use Ecto.Migration

  def change do
    create table(:incidents, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all),
        null: false

      add :issue_id, references(:issues, type: :binary_id, on_delete: :delete_all), null: false

      add :fingerprint, :string, null: false, size: 255
      add :title, :string, null: false, size: 255
      add :severity, :string, null: false, default: "info", size: 20
      add :source, :string, null: false, size: 255
      add :status, :string, null: false, default: "unresolved", size: 20
      add :muted, :boolean, null: false, default: false
      add :last_occurrence_at, :utc_datetime, null: false
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:incidents, [:account_id, :fingerprint])
    create unique_index(:incidents, [:issue_id])
    create index(:incidents, [:status])
    create index(:incidents, [:severity])
    create index(:incidents, [:last_occurrence_at])
  end
end
