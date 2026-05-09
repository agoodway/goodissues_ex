defmodule GI.Repo.Migrations.AddCurrentJobIdToChecks do
  use Ecto.Migration

  def change do
    alter table(:checks) do
      add :current_job_id, :bigint
    end
  end
end
