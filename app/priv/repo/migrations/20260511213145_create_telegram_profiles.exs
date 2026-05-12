defmodule GI.Repo.Migrations.CreateTelegramProfiles do
  use Ecto.Migration

  def change do
    create table(:telegram_profiles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :bot_token_encrypted, :binary, null: false
      add :bot_username, :string

      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:telegram_profiles, [:account_id])

    create unique_index(:telegram_profiles, [:bot_username],
             where: "bot_username IS NOT NULL",
             name: :telegram_profiles_bot_username_unique
           )
  end
end
