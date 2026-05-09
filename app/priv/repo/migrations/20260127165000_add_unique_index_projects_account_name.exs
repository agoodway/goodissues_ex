defmodule GI.Repo.Migrations.AddUniqueIndexProjectsAccountName do
  use Ecto.Migration

  def change do
    create unique_index(:projects, [:account_id, :name])
  end
end
