defmodule FF.Tracking.Project do
  @moduledoc """
  Schema for projects within accounts.
  Projects are used to organize issues and other tracking items.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "projects" do
    field :name, :string
    field :description, :string
    field :prefix, :string
    field :issue_counter, :integer, default: 1

    belongs_to :account, FF.Accounts.Account

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a project.
  """
  def create_changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :description, :prefix])
    |> maybe_trim(:name)
    |> normalize_prefix()
    |> validate_required([:name, :account_id, :prefix])
    |> validate_length(:name, max: 255)
    |> validate_length(:prefix, min: 1, max: 10)
    |> validate_format(:prefix, ~r/^[A-Z0-9]+$/,
      message: "must be uppercase letters and numbers only"
    )
    |> unique_constraint([:account_id, :name])
    |> unique_constraint(:prefix,
      name: :projects_account_id_prefix_index,
      message: "already exists in this account"
    )
    |> foreign_key_constraint(:account_id)
  end

  @doc """
  Changeset for updating a project.
  """
  def update_changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :description, :prefix])
    |> maybe_trim(:name)
    |> normalize_prefix()
    |> validate_length(:name, max: 255)
    |> validate_length(:prefix, min: 1, max: 10)
    |> validate_format(:prefix, ~r/^[A-Z0-9]+$/,
      message: "must be uppercase letters and numbers only"
    )
    |> unique_constraint([:account_id, :name])
    |> unique_constraint(:prefix,
      name: :projects_account_id_prefix_index,
      message: "already exists in this account"
    )
  end

  @max_issue_counter 2_147_483_647

  @doc """
  Changeset for incrementing the issue counter.
  Used internally when creating issues.

  Raises if the counter would overflow PostgreSQL integer range.
  """
  def increment_counter_changeset(project) do
    if project.issue_counter >= @max_issue_counter do
      raise "Issue counter overflow: project #{project.id} has reached maximum issue count"
    end

    change(project, issue_counter: project.issue_counter + 1)
  end

  defp maybe_trim(changeset, field) do
    case get_change(changeset, field) do
      nil -> changeset
      value when is_binary(value) -> put_change(changeset, field, String.trim(value))
      _ -> changeset
    end
  end

  defp normalize_prefix(changeset) do
    case get_change(changeset, :prefix) do
      nil ->
        changeset

      value when is_binary(value) ->
        put_change(changeset, :prefix, String.upcase(String.trim(value)))

      _ ->
        changeset
    end
  end

  @doc """
  Generates a suggested prefix from a project name.
  Takes the first letters of words (up to 3) and uppercases them.
  """
  def suggest_prefix(name) when is_binary(name) do
    name
    |> String.replace(~r/[^a-zA-Z0-9\s]/, "")
    |> String.split()
    |> Enum.take(3)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
    |> case do
      "" -> "PRJ"
      prefix -> prefix
    end
  end

  def suggest_prefix(_), do: "PRJ"
end
