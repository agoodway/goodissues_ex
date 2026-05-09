defmodule GI.Repo.Migrations.AddHeartbeatIdToIssues do
  use Ecto.Migration

  def change do
    alter table(:issues) do
      add :heartbeat_id, references(:heartbeats, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:issues, [:heartbeat_id])
  end
end
