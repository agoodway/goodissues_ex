defmodule GI.Repo.Migrations.AddNotNullConstraintsToPrefixAndNumber do
  use Ecto.Migration

  # Zero-downtime migration: uses NOT VALID + VALIDATE CONSTRAINT pattern
  # to avoid table locks on large tables
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    # Add NOT NULL constraints using NOT VALID (no table scan/lock)
    # then validate them separately (concurrent, no lock)
    execute(
      "ALTER TABLE projects ADD CONSTRAINT projects_prefix_not_null CHECK (prefix IS NOT NULL) NOT VALID",
      "ALTER TABLE projects DROP CONSTRAINT IF EXISTS projects_prefix_not_null"
    )

    execute(
      "ALTER TABLE projects VALIDATE CONSTRAINT projects_prefix_not_null",
      "SELECT 1"
    )

    execute(
      "ALTER TABLE issues ADD CONSTRAINT issues_number_not_null CHECK (number IS NOT NULL) NOT VALID",
      "ALTER TABLE issues DROP CONSTRAINT IF EXISTS issues_number_not_null"
    )

    execute(
      "ALTER TABLE issues VALIDATE CONSTRAINT issues_number_not_null",
      "SELECT 1"
    )

    # Create unique indexes concurrently for zero-downtime
    create unique_index(:projects, [:account_id, :prefix], concurrently: true)
    create unique_index(:issues, [:project_id, :number], concurrently: true)
  end
end
