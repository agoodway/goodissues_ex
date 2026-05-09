defmodule GI.Repo.Migrations.CreateChecks do
  use Ecto.Migration

  def change do
    create table(:checks, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :name, :string, null: false, size: 255
      add :url, :string, null: false, size: 2048
      add :method, :string, null: false, default: "GET", size: 10
      add :interval_seconds, :integer, null: false, default: 300
      add :expected_status, :integer, null: false, default: 200
      add :keyword, :string, size: 255
      add :keyword_absence, :boolean, null: false, default: false
      add :paused, :boolean, null: false, default: false
      add :status, :string, null: false, default: "unknown", size: 20
      add :failure_threshold, :integer, null: false, default: 1
      add :reopen_window_hours, :integer, null: false, default: 24
      add :consecutive_failures, :integer, null: false, default: 0
      add :last_checked_at, :utc_datetime

      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all),
        null: false

      add :current_issue_id, references(:issues, type: :binary_id, on_delete: :nilify_all)

      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:checks, [:project_id])
    create index(:checks, [:current_issue_id])
    create index(:checks, [:paused])
  end
end
