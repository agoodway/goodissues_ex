defmodule GI.Monitoring.HeartbeatPing do
  @moduledoc """
  Schema for a heartbeat ping record. Read-only after insert.

  Each ping records the kind of signal received (`:ping` for success,
  `:start` for job-started, `:fail` for explicit failure), an optional
  JSON payload, computed duration, and optional exit code.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @kind_values [:ping, :start, :fail]

  schema "heartbeat_pings" do
    field :kind, Ecto.Enum, values: @kind_values
    field :exit_code, :integer
    field :payload, :map
    field :duration_ms, :integer
    field :pinged_at, :utc_datetime_usec

    belongs_to :heartbeat, GI.Monitoring.Heartbeat
    belongs_to :issue, GI.Tracking.Issue

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def kind_values, do: @kind_values

  @doc "Changeset for creating a new heartbeat ping. Immutable after insert."
  def create_changeset(ping, attrs) do
    ping
    |> cast(attrs, [
      :kind,
      :exit_code,
      :payload,
      :duration_ms,
      :pinged_at,
      :heartbeat_id,
      :issue_id
    ])
    |> validate_required([:kind, :pinged_at, :heartbeat_id])
    |> validate_inclusion(:kind, @kind_values)
    |> validate_number(:exit_code,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 255
    )
    |> foreign_key_constraint(:heartbeat_id)
    |> foreign_key_constraint(:issue_id)
  end
end
