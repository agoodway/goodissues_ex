defmodule GI.Repo.Migrations.AddNumberToIssues do
  use Ecto.Migration

  def change do
    alter table(:issues) do
      add :number, :integer
    end
  end
end
