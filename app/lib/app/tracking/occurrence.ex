defmodule FF.Tracking.Occurrence do
  @moduledoc """
  Schema for error occurrences.
  Each occurrence represents a single instance of an error with context and stacktrace.
  Occurrences are immutable (no updated_at).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "occurrences" do
    field :reason, :string
    field :context, :map, default: %{}
    field :breadcrumbs, {:array, :string}, default: []

    belongs_to :error, FF.Tracking.Error
    has_many :stacktrace_lines, FF.Tracking.StacktraceLine

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Changeset for creating an occurrence.
  """
  @max_breadcrumbs 100
  @max_context_keys 50

  def create_changeset(occurrence, attrs) do
    occurrence
    |> cast(attrs, [:reason, :context, :breadcrumbs])
    |> validate_required([:error_id])
    |> validate_length(:breadcrumbs, max: @max_breadcrumbs)
    |> validate_context()
    |> foreign_key_constraint(:error_id)
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
