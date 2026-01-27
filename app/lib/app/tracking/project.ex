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

    belongs_to :account, FF.Accounts.Account

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a project.
  """
  def create_changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :description])
    |> validate_required([:name, :account_id])
    |> validate_length(:name, max: 255)
    |> maybe_trim(:name)
    |> unique_constraint([:account_id, :name])
    |> foreign_key_constraint(:account_id)
  end

  @doc """
  Changeset for updating a project.
  """
  def update_changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :description])
    |> validate_length(:name, max: 255)
    |> maybe_trim(:name)
    |> unique_constraint([:account_id, :name])
  end

  defp maybe_trim(changeset, field) do
    case get_change(changeset, field) do
      nil -> changeset
      value when is_binary(value) -> put_change(changeset, field, String.trim(value))
      _ -> changeset
    end
  end
end
