defmodule FF.Repo.Migrations.CreateHeartbeats do
  use Ecto.Migration

  def change do
    create table(:heartbeats, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :name, :string, null: false, size: 255
      add :ping_token, :string, null: false, size: 42
      add :interval_seconds, :integer, null: false, default: 300
      add :grace_seconds, :integer, null: false, default: 0
      add :failure_threshold, :integer, null: false, default: 1
      add :reopen_window_hours, :integer, null: false, default: 24
      add :status, :string, null: false, default: "unknown", size: 20
      add :consecutive_failures, :integer, null: false, default: 0
      add :last_ping_at, :utc_datetime
      add :next_due_at, :utc_datetime
      add :started_at, :utc_datetime_usec
      add :paused, :boolean, null: false, default: false
      add :alert_rules, :jsonb, null: false, default: "[]"

      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all),
        null: false

      add :current_issue_id, references(:issues, type: :binary_id, on_delete: :nilify_all)

      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:heartbeats, [:ping_token])
    create index(:heartbeats, [:project_id])
    create index(:heartbeats, [:current_issue_id])
    create index(:heartbeats, [:paused])
  end
end
