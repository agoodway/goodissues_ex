defmodule GI.Repo.Migrations.AddPrefixAndIssueCounterToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :prefix, :string, size: 10
      add :issue_counter, :integer, default: 1
    end
  end
end
