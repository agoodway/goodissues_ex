defmodule GI.Tracking.Incident do
  @moduledoc """
  Schema for incidents linked to issues.
  Incidents store metadata about operational incidents with fingerprint-based deduplication.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @severity_values [:info, :warning, :critical]
  @status_values [:resolved, :unresolved]

  schema "incidents" do
    field :fingerprint, :string
    field :title, :string
    field :severity, Ecto.Enum, values: @severity_values, default: :info
    field :source, :string
    field :status, Ecto.Enum, values: @status_values, default: :unresolved
    field :muted, :boolean, default: false
    field :last_occurrence_at, :utc_datetime
    field :metadata, :map, default: %{}

    belongs_to :account, GI.Accounts.Account
    belongs_to :issue, GI.Tracking.Issue
    has_many :incident_occurrences, GI.Tracking.IncidentOccurrence

    field :occurrence_count, :integer, virtual: true

    timestamps(type: :utc_datetime)
  end

  def severity_values, do: @severity_values
  def status_values, do: @status_values

  def create_changeset(incident, attrs) do
    incident
    |> cast(attrs, [
      :fingerprint,
      :title,
      :severity,
      :source,
      :status,
      :muted,
      :last_occurrence_at,
      :metadata,
      :issue_id,
      :account_id
    ])
    |> validate_required([
      :fingerprint,
      :title,
      :severity,
      :source,
      :last_occurrence_at,
      :issue_id,
      :account_id
    ])
    |> validate_length(:fingerprint, max: 255)
    |> validate_length(:title, max: 255)
    |> validate_length(:source, max: 255)
    |> validate_inclusion(:severity, @severity_values)
    |> unique_constraint([:account_id, :fingerprint])
    |> unique_constraint(:issue_id)
    |> foreign_key_constraint(:issue_id)
    |> foreign_key_constraint(:account_id)
  end

  def update_changeset(incident, attrs) do
    incident
    |> cast(attrs, [:status, :muted, :last_occurrence_at, :issue_id])
    |> validate_inclusion(:status, @status_values)
  end
end
