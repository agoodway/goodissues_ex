defmodule FF.Tracking.Issue do
  @moduledoc """
  Schema for issues within projects.
  Issues track bugs and feature requests.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type_values [:bug, :feature_request]
  @status_values [:new, :in_progress, :archived]
  @priority_values [:low, :medium, :high, :critical]

  schema "issues" do
    field :title, :string
    field :description, :string
    field :type, Ecto.Enum, values: @type_values
    field :status, Ecto.Enum, values: @status_values, default: :new
    field :priority, Ecto.Enum, values: @priority_values, default: :medium
    field :submitter_email, :string
    field :archived_at, :utc_datetime

    belongs_to :project, FF.Tracking.Project
    belongs_to :submitter, FF.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def type_values, do: @type_values
  def status_values, do: @status_values
  def priority_values, do: @priority_values

  @doc """
  Changeset for creating an issue.
  """
  def create_changeset(issue, attrs) do
    issue
    |> cast(attrs, [:title, :description, :type, :status, :priority, :submitter_email])
    |> validate_required([:title, :type, :project_id, :submitter_id])
    |> validate_length(:title, max: 255)
    |> validate_length(:description, max: 10_000)
    |> validate_length(:submitter_email, max: 255)
    |> validate_format(:submitter_email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must be a valid email"
    )
    |> maybe_trim(:title)
    |> manage_archived_at()
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:submitter_id)
  end

  @doc """
  Changeset for updating an issue.
  """
  def update_changeset(issue, attrs) do
    issue
    |> cast(attrs, [:title, :description, :type, :status, :priority, :submitter_email])
    |> validate_length(:title, max: 255)
    |> validate_length(:description, max: 10_000)
    |> validate_length(:submitter_email, max: 255)
    |> validate_format(:submitter_email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must be a valid email"
    )
    |> maybe_trim(:title)
    |> manage_archived_at()
  end

  defp maybe_trim(changeset, field) do
    case get_change(changeset, field) do
      nil -> changeset
      value when is_binary(value) -> put_change(changeset, field, String.trim(value))
      _ -> changeset
    end
  end

  defp manage_archived_at(changeset) do
    case get_change(changeset, :status) do
      :archived ->
        put_change(changeset, :archived_at, DateTime.utc_now(:second))

      nil ->
        changeset

      _other_status ->
        # Transitioning away from archived: clear archived_at
        if get_field(changeset, :archived_at) do
          put_change(changeset, :archived_at, nil)
        else
          changeset
        end
    end
  end
end
