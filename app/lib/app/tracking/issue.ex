defmodule FF.Tracking.Issue do
  @moduledoc """
  Schema for issues within projects.
  Issues track bugs, incidents, and feature requests.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type_values [:bug, :incident, :feature_request]
  @status_values [:new, :in_progress, :archived]
  @priority_values [:low, :medium, :high, :critical]

  schema "issues" do
    field :title, :string
    field :description, :string
    field :number, :integer
    field :type, Ecto.Enum, values: @type_values
    field :status, Ecto.Enum, values: @status_values, default: :new
    field :priority, Ecto.Enum, values: @priority_values, default: :medium
    field :submitter_email, :string
    field :archived_at, :utc_datetime

    belongs_to :project, FF.Tracking.Project
    belongs_to :submitter, FF.Accounts.User
    has_one :error, FF.Tracking.Error

    timestamps(type: :utc_datetime)
  end

  def type_values, do: @type_values
  def status_values, do: @status_values
  def priority_values, do: @priority_values

  @doc """
  Returns the human-readable issue key in the format "PREFIX-NUMBER".
  Requires the project to be preloaded with the prefix field.

  ## Examples

      iex> issue_key(%Issue{number: 42, project: %Project{prefix: "FF"}})
      "FF-42"

  """
  def issue_key(%__MODULE__{number: number, project: %{prefix: prefix}})
      when is_integer(number) and is_binary(prefix) do
    "#{prefix}-#{number}"
  end

  def issue_key(_), do: nil

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
    |> unique_constraint(:number, name: :issues_project_id_number_index)
  end

  @doc """
  Changeset for updating an issue.
  """
  def update_changeset(issue, attrs) do
    issue
    |> cast(attrs, [:title, :description, :type, :status, :priority, :submitter_email])
    |> maybe_trim(:title)
    |> validate_not_blank_if_changed_to_nil(:title)
    |> validate_enum_not_nil(:type, @type_values)
    |> validate_enum_not_nil(:status, @status_values)
    |> validate_enum_not_nil(:priority, @priority_values)
    |> validate_length(:title, max: 255)
    |> validate_length(:description, max: 10_000)
    |> validate_length(:submitter_email, max: 255)
    |> validate_format(:submitter_email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must be a valid email"
    )
    |> manage_archived_at()
  end

  defp validate_enum_not_nil(changeset, field, valid_values) do
    # Check if the field was explicitly changed to nil (from a form submitting empty string)
    if Map.has_key?(changeset.changes, field) && get_change(changeset, field) == nil do
      valid_options = Enum.map_join(valid_values, ", ", &to_string/1)
      add_error(changeset, field, "must be one of: #{valid_options}")
    else
      changeset
    end
  end

  defp validate_not_blank_if_changed_to_nil(changeset, field) do
    # When a form sends "" for a string field, Ecto casts it to nil.
    # If the field is being changed to nil, add validation error.
    if Map.has_key?(changeset.changes, field) && get_change(changeset, field) == nil do
      add_error(changeset, field, "can't be blank")
    else
      changeset
    end
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
