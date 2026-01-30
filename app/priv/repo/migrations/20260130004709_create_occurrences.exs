defmodule FF.Repo.Migrations.CreateOccurrences do
  use Ecto.Migration

  def change do
    create table(:occurrences, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :error_id, references(:errors, type: :binary_id, on_delete: :delete_all), null: false

      add :reason, :text
      add :context, :map, default: %{}
      add :breadcrumbs, {:array, :string}, default: []

      add :inserted_at, :utc_datetime, null: false
    end

    create index(:occurrences, [:error_id])
    create index(:occurrences, [:error_id, :inserted_at])
  end
end
