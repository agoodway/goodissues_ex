defmodule GI.Repo.Migrations.CreateIncidentOccurrences do
  use Ecto.Migration

  def change do
    create table(:incident_occurrences, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :incident_id, references(:incidents, type: :binary_id, on_delete: :delete_all),
        null: false

      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all),
        null: false

      add :context, :map, default: %{}

      add :inserted_at, :utc_datetime, null: false
    end

    create index(:incident_occurrences, [:incident_id])
    create index(:incident_occurrences, [:incident_id, :inserted_at])
    create index(:incident_occurrences, [:account_id])
  end
end
