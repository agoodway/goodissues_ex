defmodule FF.Repo.Migrations.BackfillProjectPrefixesAndIssueNumbers do
  use Ecto.Migration

  def up do
    # Generate prefixes from project names (first 3 alphanumeric chars, uppercase)
    execute """
    UPDATE projects
    SET prefix = UPPER(SUBSTRING(REGEXP_REPLACE(name, '[^a-zA-Z0-9]', '', 'g'), 1, 3))
    WHERE prefix IS NULL
    """

    # Handle edge case: if prefix ends up empty, set to 'PRJ'
    execute """
    UPDATE projects
    SET prefix = 'PRJ'
    WHERE prefix IS NULL OR prefix = ''
    """

    # Handle duplicate prefixes within the same account by appending numbers
    execute """
    WITH duplicates AS (
      SELECT id, account_id, prefix,
             ROW_NUMBER() OVER (PARTITION BY account_id, prefix ORDER BY inserted_at) as rn
      FROM projects
    )
    UPDATE projects
    SET prefix = duplicates.prefix || duplicates.rn
    FROM duplicates
    WHERE projects.id = duplicates.id AND duplicates.rn > 1
    """

    # Assign issue numbers by insertion order within each project
    execute """
    WITH numbered AS (
      SELECT id, ROW_NUMBER() OVER (PARTITION BY project_id ORDER BY inserted_at) as num
      FROM issues
    )
    UPDATE issues SET number = numbered.num
    FROM numbered WHERE issues.id = numbered.id
    """

    # Update issue_counter to next available number for each project
    execute """
    UPDATE projects
    SET issue_counter = COALESCE(
      (SELECT MAX(number) + 1 FROM issues WHERE issues.project_id = projects.id),
      1
    )
    """
  end

  def down do
    execute "UPDATE projects SET prefix = NULL, issue_counter = 1"
    execute "UPDATE issues SET number = NULL"
  end
end
