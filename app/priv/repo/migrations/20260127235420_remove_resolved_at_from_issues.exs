defmodule FF.Repo.Migrations.RemoveResolvedAtFromIssues do
  use Ecto.Migration

  def change do
    alter table(:issues) do
      remove :resolved_at, :utc_datetime
    end
  end
end
