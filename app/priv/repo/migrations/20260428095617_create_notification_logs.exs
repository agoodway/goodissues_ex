defmodule FF.Repo.Migrations.CreateNotificationLogs do
  use Ecto.Migration

  def change do
    create table(:notification_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_type, :string, null: false

      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all),
        null: false

      add :subscription_id,
          references(:event_subscriptions, type: :binary_id, on_delete: :nilify_all)

      add :destination, :string, null: false
      add :channel, :string, null: false
      add :status, :string, null: false
      add :error, :text
      add :resource_type, :string
      add :resource_id, :binary_id

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:notification_logs, [:account_id, :inserted_at])
    create index(:notification_logs, [:subscription_id])
    create index(:notification_logs, [:status])
  end
end
