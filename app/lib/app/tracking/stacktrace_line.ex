defmodule FF.Tracking.StacktraceLine do
  @moduledoc """
  Schema for stacktrace lines within an occurrence.
  Each line represents a frame in the error stacktrace, enabling search by module/function/file.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "stacktrace_lines" do
    field :position, :integer
    field :application, :string
    field :module, :string
    field :function, :string
    field :arity, :integer
    field :file, :string
    field :line, :integer

    belongs_to :occurrence, FF.Tracking.Occurrence
  end

  @doc """
  Changeset for creating a stacktrace line.
  """
  def create_changeset(stacktrace_line, attrs) do
    stacktrace_line
    |> cast(attrs, [:position, :application, :module, :function, :arity, :file, :line])
    |> validate_required([:position, :occurrence_id])
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> validate_length(:application, max: 255)
    |> validate_length(:module, max: 255)
    |> validate_length(:function, max: 255)
    |> validate_length(:file, max: 500)
    |> foreign_key_constraint(:occurrence_id)
  end
end
