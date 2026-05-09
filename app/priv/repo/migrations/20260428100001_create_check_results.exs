defmodule GI.Repo.Migrations.CreateCheckResults do
  use Ecto.Migration

  def change do
    create table(:check_results, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :status, :string, null: false, size: 20
      add :status_code, :integer
      add :response_ms, :integer
      add :error, :text
      add :checked_at, :utc_datetime, null: false

      add :check_id, references(:checks, type: :binary_id, on_delete: :delete_all), null: false
      add :issue_id, references(:issues, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:check_results, [:check_id])
    create index(:check_results, [:check_id, :checked_at])
  end
end
