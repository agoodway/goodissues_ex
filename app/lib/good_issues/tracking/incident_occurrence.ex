defmodule GI.Tracking.IncidentOccurrence do
  @moduledoc """
  Schema for incident occurrences.
  Each occurrence represents a single instance of an incident with context.
  Occurrences are immutable (no updated_at).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @max_context_keys 50

  schema "incident_occurrences" do
    field :context, :map, default: %{}

    belongs_to :incident, GI.Tracking.Incident

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def create_changeset(occurrence, attrs) do
    occurrence
    |> cast(attrs, [:context])
    |> validate_required([:incident_id])
    |> validate_context()
    |> foreign_key_constraint(:incident_id)
  end

  defp validate_context(changeset) do
    case get_field(changeset, :context) do
      nil ->
        changeset

      context when is_map(context) ->
        if map_size(context) > @max_context_keys do
          add_error(changeset, :context, "cannot have more than #{@max_context_keys} keys")
        else
          changeset
        end

      _ ->
        add_error(changeset, :context, "must be a map")
    end
  end
end
