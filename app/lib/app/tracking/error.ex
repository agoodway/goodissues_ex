defmodule FF.Tracking.Error do
  @moduledoc """
  Schema for errors linked to issues.
  Errors store metadata about application errors with fingerprint-based deduplication.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @status_values [:resolved, :unresolved]

  schema "errors" do
    field :kind, :string
    field :reason, :string
    field :source_line, :string, default: "-"
    field :source_function, :string, default: "-"
    field :status, Ecto.Enum, values: @status_values, default: :unresolved
    field :fingerprint, :string
    field :last_occurrence_at, :utc_datetime
    field :muted, :boolean, default: false

    belongs_to :issue, FF.Tracking.Issue
    has_many :occurrences, FF.Tracking.Occurrence

    timestamps(type: :utc_datetime)
  end

  def status_values, do: @status_values

  @doc """
  Changeset for creating an error.
  """
  def create_changeset(error, attrs) do
    error
    |> cast(attrs, [
      :kind,
      :reason,
      :source_line,
      :source_function,
      :fingerprint,
      :last_occurrence_at,
      :muted,
      :issue_id
    ])
    |> validate_required([:kind, :reason, :fingerprint, :last_occurrence_at, :issue_id])
    |> validate_length(:kind, max: 255)
    |> validate_length(:source_line, max: 255)
    |> validate_length(:source_function, max: 255)
    |> validate_length(:fingerprint, is: 64)
    |> unique_constraint(:issue_id)
    |> foreign_key_constraint(:issue_id)
  end

  @doc """
  Changeset for updating an error.
  """
  def update_changeset(error, attrs) do
    error
    |> cast(attrs, [:status, :last_occurrence_at, :muted])
    |> validate_inclusion(:status, @status_values)
  end
end
