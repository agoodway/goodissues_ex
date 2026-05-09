defmodule GI.Repo.Migrations.CreateHeartbeatPings do
  use Ecto.Migration

  def change do
    create table(:heartbeat_pings, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :kind, :string, null: false, size: 10
      add :exit_code, :integer
      add :payload, :jsonb
      add :duration_ms, :integer
      add :pinged_at, :utc_datetime_usec, null: false

      add :heartbeat_id,
          references(:heartbeats, type: :binary_id, on_delete: :delete_all),
          null: false

      add :issue_id, references(:issues, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:heartbeat_pings, [:heartbeat_id])
    create index(:heartbeat_pings, [:heartbeat_id, :pinged_at])
  end
end
