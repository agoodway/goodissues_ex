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
  @max_json_bytes 65_536
  @max_json_depth 5

  schema "incident_occurrences" do
    field :context, :map, default: %{}

    belongs_to :incident, GI.Tracking.Incident
    belongs_to :account, GI.Accounts.Account

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def create_changeset(occurrence, attrs) do
    occurrence
    |> cast(attrs, [:context, :incident_id, :account_id])
    |> validate_required([:incident_id, :account_id])
    |> validate_context()
    |> foreign_key_constraint(:incident_id)
    |> foreign_key_constraint(:account_id)
  end

  defp validate_context(changeset) do
    case get_field(changeset, :context) do
      nil ->
        changeset

      context when is_map(context) ->
        cond do
          map_size(context) > @max_context_keys ->
            add_error(changeset, :context, "cannot have more than #{@max_context_keys} keys")

          json_byte_size(context) > @max_json_bytes ->
            add_error(changeset, :context, "exceeds maximum size of #{@max_json_bytes} bytes")

          json_depth(context) > @max_json_depth ->
            add_error(changeset, :context, "exceeds maximum nesting depth of #{@max_json_depth}")

          true ->
            changeset
        end

      _ ->
        add_error(changeset, :context, "must be a map")
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
