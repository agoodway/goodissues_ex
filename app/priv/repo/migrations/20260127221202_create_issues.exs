defmodule FF.Repo.Migrations.CreateIssues do
  use Ecto.Migration

  def change do
    create table(:issues, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false, size: 255
      add :description, :text
      add :type, :string, null: false, size: 20
      add :status, :string, null: false, default: "new", size: 20
      add :priority, :string, null: false, default: "medium", size: 20
      add :submitter_email, :string, size: 255

      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all),
        null: false

      add :submitter_id, references(:users, type: :binary_id, on_delete: :restrict), null: false

      add :resolved_at, :utc_datetime
      add :archived_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:issues, [:project_id])
    create index(:issues, [:status])
    create index(:issues, [:type])
    create index(:issues, [:project_id, :status])
    create index(:issues, [:project_id, :inserted_at])
    create index(:issues, [:submitter_id])
  end
end
