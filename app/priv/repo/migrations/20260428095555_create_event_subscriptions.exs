defmodule FF.Repo.Migrations.CreateEventSubscriptions do
  use Ecto.Migration

  def change do
    create table(:event_subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_types, {:array, :string}, null: false, default: []
      add :channel, :string, null: false
      add :destination, :string
      add :criteria, :string
      add :secret, :string
      add :active, :boolean, null: false, default: true
      add :name, :string

      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create constraint(:event_subscriptions, :event_subscriptions_channel_check,
             check: "channel IN ('email', 'webhook')"
           )

    create index(:event_subscriptions, [:account_id])

    create unique_index(
             :event_subscriptions,
             [:account_id, :channel, :destination],
             where: "destination IS NOT NULL",
             name: :event_subscriptions_static_destination_index
           )

    create unique_index(
             :event_subscriptions,
             [:account_id, :channel, :user_id],
             where: "user_id IS NOT NULL",
             name: :event_subscriptions_user_linked_index
           )
  end
end
