defmodule GI.Repo.Migrations.CreateApiKeys do
  use Ecto.Migration

  def change do
    create table(:api_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :type, :string, null: false, default: "public"
      add :token_prefix, :string, null: false
      add :token_hash, :string, null: false
      add :status, :string, null: false, default: "active"
      add :last_used_at, :utc_datetime
      add :expires_at, :utc_datetime

      add :account_user_id, references(:account_users, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create index(:api_keys, [:account_user_id])
    create index(:api_keys, [:token_prefix])
    create unique_index(:api_keys, [:token_hash])
    create index(:api_keys, [:status])
  end
end
