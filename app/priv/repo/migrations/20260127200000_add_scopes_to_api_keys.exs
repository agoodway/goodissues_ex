defmodule GI.Repo.Migrations.AddScopesToApiKeys do
  use Ecto.Migration

  def change do
    alter table(:api_keys) do
      add :scopes, {:array, :string}, default: [], null: false
    end
  end
end
