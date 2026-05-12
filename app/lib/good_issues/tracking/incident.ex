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
  @max_metadata_keys 50
  @max_json_bytes 65_536
  @max_json_depth 5

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
    |> validate_metadata()
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

  defp validate_metadata(changeset) do
    case get_field(changeset, :metadata) do
      nil ->
        changeset

      metadata when is_map(metadata) ->
        cond do
          map_size(metadata) > @max_metadata_keys ->
            add_error(changeset, :metadata, "cannot have more than #{@max_metadata_keys} keys")

          json_byte_size(metadata) > @max_json_bytes ->
            add_error(changeset, :metadata, "exceeds maximum size of #{@max_json_bytes} bytes")

          json_depth(metadata) > @max_json_depth ->
            add_error(changeset, :metadata, "exceeds maximum nesting depth of #{@max_json_depth}")

          true ->
            changeset
        end

      _ ->
        add_error(changeset, :metadata, "must be a map")
    end
  end

  defp json_byte_size(data), do: data |> Jason.encode!() |> byte_size()

  defp json_depth(data) when is_map(data) and map_size(data) == 0, do: 0

  defp json_depth(data) when is_map(data) do
    1 + (data |> Map.values() |> Enum.map(&json_depth/1) |> Enum.max(fn -> 0 end))
  end

  defp json_depth(data) when is_list(data) and length(data) == 0, do: 0

  defp json_depth(data) when is_list(data) do
    1 + (data |> Enum.map(&json_depth/1) |> Enum.max(fn -> 0 end))
  end

  defp json_depth(_), do: 0
end
