defmodule FF.Monitoring.CheckResult do
  @moduledoc """
  Schema for an immutable check execution record.

  Each row is the outcome of one HTTP check: whether it was up or down,
  the HTTP status code observed, latency, and any error encountered.
  Results are append-only — there is no update changeset.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @status_values [:up, :down]

  schema "check_results" do
    field :status, Ecto.Enum, values: @status_values
    field :status_code, :integer
    field :response_ms, :integer
    field :error, :string
    field :checked_at, :utc_datetime

    belongs_to :check, FF.Monitoring.Check
    belongs_to :issue, FF.Tracking.Issue

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def status_values, do: @status_values

  @doc "Changeset for inserting a new check result. Results are immutable after insert."
  def create_changeset(result, attrs) do
    result
    |> cast(attrs, [
      :status,
      :status_code,
      :response_ms,
      :error,
      :checked_at,
      :check_id,
      :issue_id
    ])
    |> validate_required([:status, :checked_at, :check_id])
    |> validate_inclusion(:status, @status_values)
    |> validate_number(:response_ms, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:check_id)
    |> foreign_key_constraint(:issue_id)
  end
end
