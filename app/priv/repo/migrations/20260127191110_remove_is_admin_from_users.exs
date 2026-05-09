defmodule GI.Repo.Migrations.RemoveIsAdminFromUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :is_admin, :boolean, default: false, null: false
    end
  end
end
