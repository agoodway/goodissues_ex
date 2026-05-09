defmodule GI.Repo.Migrations.HashHeartbeatPingTokens do
  use Ecto.Migration

  def change do
    alter table(:heartbeats) do
      add :ping_token_hash, :string, size: 64
    end

    # Populate hashes from existing plaintext tokens
    execute(
      "UPDATE heartbeats SET ping_token_hash = encode(sha256(ping_token::bytea), 'hex')",
      "SELECT 1"
    )

    alter table(:heartbeats) do
      modify :ping_token_hash, :string, null: false, size: 64
    end

    # Replace the unique index on plaintext token with one on hash
    drop unique_index(:heartbeats, [:ping_token])
    create unique_index(:heartbeats, [:ping_token_hash])

    # Add payload size CHECK constraint
    execute(
      "ALTER TABLE heartbeat_pings ADD CONSTRAINT heartbeat_pings_payload_size CHECK (octet_length(payload::text) <= 4096)",
      "ALTER TABLE heartbeat_pings DROP CONSTRAINT heartbeat_pings_payload_size"
    )

    # Add partial composite index for orphaned_heartbeats query
    drop index(:heartbeats, [:paused])

    create index(:heartbeats, [:next_due_at],
             where: "paused = false AND next_due_at IS NOT NULL",
             name: :heartbeats_active_due_idx
           )

    # Add partial index on heartbeat_pings.issue_id
    create index(:heartbeat_pings, [:issue_id],
             where: "issue_id IS NOT NULL",
             name: :heartbeat_pings_issue_id_idx
           )
  end
end
