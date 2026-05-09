defmodule FF.Monitoring.Heartbeat do
  @moduledoc """
  Schema for a heartbeat monitor scoped to a project.

  Heartbeats invert the uptime check model: instead of FruitFly reaching
  out, external jobs ping FruitFly via a unique token URL to prove they
  are running. If a ping doesn't arrive before the deadline
  (`next_due_at`), the system creates an incident.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @status_values [:unknown, :up, :down]
  @min_interval 30
  @max_interval 86_400
  @max_grace 86_400
  @token_length 42
  @allowed_ops ~w(eq neq gt gte lt lte)

  schema "heartbeats" do
    field :name, :string
    field :ping_token, :string
    field :ping_token_hash, :string
    field :interval_seconds, :integer, default: 300
    field :grace_seconds, :integer, default: 0
    field :failure_threshold, :integer, default: 1
    field :reopen_window_hours, :integer, default: 24
    field :status, Ecto.Enum, values: @status_values, default: :unknown
    field :consecutive_failures, :integer, default: 0
    field :last_ping_at, :utc_datetime
    field :next_due_at, :utc_datetime
    field :started_at, :utc_datetime_usec
    field :paused, :boolean, default: false
    field :alert_rules, {:array, :map}, default: []

    belongs_to :project, FF.Tracking.Project
    belongs_to :current_issue, FF.Tracking.Issue
    belongs_to :created_by, FF.Accounts.User

    has_many :pings, FF.Monitoring.HeartbeatPing

    timestamps(type: :utc_datetime)
  end

  def status_values, do: @status_values
  def token_length, do: @token_length

  @doc "Generates a cryptographically random 42-character URL-safe token."
  def generate_token do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
    |> binary_part(0, @token_length)
  end

  @doc "Computes the SHA-256 hex hash of a ping token."
  def hash_token(token) when is_binary(token) do
    :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)
  end

  @doc "Changeset for creating a new heartbeat."
  def create_changeset(heartbeat, attrs) do
    heartbeat
    |> cast(attrs, [
      :name,
      :interval_seconds,
      :grace_seconds,
      :failure_threshold,
      :reopen_window_hours,
      :paused,
      :alert_rules,
      :project_id,
      :created_by_id,
      :ping_token,
      :next_due_at
    ])
    |> validate_required([:name, :project_id, :ping_token])
    |> put_token_hash()
    |> common_validations()
    |> validate_alert_rules()
    |> unique_constraint(:ping_token_hash, name: :heartbeats_ping_token_hash_index)
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:created_by_id)
  end

  @doc "Changeset for updating an existing heartbeat."
  def update_changeset(heartbeat, attrs) do
    heartbeat
    |> cast(attrs, [
      :name,
      :interval_seconds,
      :grace_seconds,
      :failure_threshold,
      :reopen_window_hours,
      :paused,
      :alert_rules
    ])
    |> common_validations()
    |> validate_alert_rules()
  end

  @doc """
  Internal changeset for runtime fields updated by workers and
  lifecycle modules. Not exposed via the public API.
  """
  def runtime_changeset(heartbeat, attrs) do
    heartbeat
    |> cast(attrs, [
      :status,
      :consecutive_failures,
      :last_ping_at,
      :next_due_at,
      :started_at,
      :current_issue_id
    ])
    |> validate_number(:consecutive_failures, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:current_issue_id)
  end

  defp put_token_hash(changeset) do
    case get_change(changeset, :ping_token) do
      nil -> changeset
      token -> put_change(changeset, :ping_token_hash, hash_token(token))
    end
  end

  defp common_validations(changeset) do
    changeset
    |> validate_length(:name, max: 255)
    |> validate_number(:interval_seconds,
      greater_than_or_equal_to: @min_interval,
      less_than_or_equal_to: @max_interval
    )
    |> validate_number(:grace_seconds,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: @max_grace
    )
    |> validate_number(:failure_threshold, greater_than_or_equal_to: 1)
    |> validate_number(:reopen_window_hours, greater_than_or_equal_to: 1)
  end

  @doc "Validates the alert_rules field structure."
  def validate_alert_rules(changeset) do
    validate_change(changeset, :alert_rules, fn :alert_rules, rules ->
      case validate_rules_list(rules) do
        :ok -> []
        {:error, msg} -> [alert_rules: msg]
      end
    end)
  end

  defp validate_rules_list(rules) when is_list(rules) do
    Enum.reduce_while(rules, :ok, fn rule, :ok ->
      case validate_single_rule(rule) do
        :ok -> {:cont, :ok}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp validate_rules_list(_), do: {:error, "must be a list"}

  defp validate_single_rule(%{"field" => field, "op" => op, "value" => value})
       when is_binary(field) and is_binary(op) do
    cond do
      String.contains?(field, ".") ->
        {:error, "nested field paths are not supported"}

      op not in @allowed_ops ->
        {:error, "unsupported operator: #{op}"}

      not json_scalar?(value) ->
        {:error, "rule value must be a JSON scalar (string, number, boolean, or null)"}

      true ->
        :ok
    end
  end

  defp validate_single_rule(%{field: field, op: op, value: value})
       when is_binary(field) and is_binary(op) do
    validate_single_rule(%{"field" => field, "op" => op, "value" => value})
  end

  defp validate_single_rule(_), do: {:error, "each rule must have field, op, and value keys"}

  defp json_scalar?(nil), do: true
  defp json_scalar?(v) when is_binary(v), do: true
  defp json_scalar?(v) when is_number(v), do: true
  defp json_scalar?(v) when is_boolean(v), do: true
  defp json_scalar?(_), do: false
end
