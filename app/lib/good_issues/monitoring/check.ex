defmodule GI.Monitoring.Check do
  @moduledoc """
  Schema for an HTTP uptime check scoped to a project.

  A check defines how to monitor a URL: the HTTP method, expected status,
  optional keyword match, polling interval, failure threshold, and the
  window in which a recently archived incident issue is reopened instead
  of creating a new one.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @method_values [:get, :head, :post]
  @status_values [:unknown, :up, :down]
  @min_interval 30
  @max_interval 3600

  schema "checks" do
    field :name, :string
    field :url, :string
    field :method, Ecto.Enum, values: @method_values, default: :get
    field :interval_seconds, :integer, default: 300
    field :expected_status, :integer, default: 200
    field :keyword, :string
    field :keyword_absence, :boolean, default: false
    field :paused, :boolean, default: false
    field :status, Ecto.Enum, values: @status_values, default: :unknown
    field :failure_threshold, :integer, default: 1
    field :reopen_window_hours, :integer, default: 24
    field :consecutive_failures, :integer, default: 0
    field :last_checked_at, :utc_datetime
    field :current_job_id, :integer

    belongs_to :project, GI.Tracking.Project
    belongs_to :current_issue, GI.Tracking.Issue
    belongs_to :created_by, GI.Accounts.User

    has_many :results, GI.Monitoring.CheckResult

    timestamps(type: :utc_datetime)
  end

  def method_values, do: @method_values
  def status_values, do: @status_values

  @doc "Changeset for creating a new check."
  def create_changeset(check, attrs) do
    check
    |> cast(attrs, [
      :name,
      :url,
      :method,
      :interval_seconds,
      :expected_status,
      :keyword,
      :keyword_absence,
      :paused,
      :failure_threshold,
      :reopen_window_hours,
      :project_id,
      :created_by_id
    ])
    |> validate_required([:name, :url, :project_id])
    |> common_validations()
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:created_by_id)
  end

  @doc "Changeset for updating an existing check."
  def update_changeset(check, attrs) do
    check
    |> cast(attrs, [
      :name,
      :url,
      :method,
      :interval_seconds,
      :expected_status,
      :keyword,
      :keyword_absence,
      :paused,
      :failure_threshold,
      :reopen_window_hours
    ])
    |> common_validations()
  end

  @doc """
  Internal changeset used by the worker / lifecycle to update runtime
  fields like status, consecutive_failures, last_checked_at, current_issue_id.
  Not exposed via the public CRUD API.
  """
  def runtime_changeset(check, attrs) do
    check
    |> cast(attrs, [
      :status,
      :consecutive_failures,
      :last_checked_at,
      :current_issue_id,
      :current_job_id
    ])
    |> validate_number(:consecutive_failures, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:current_issue_id)
  end

  defp common_validations(changeset) do
    changeset
    |> validate_length(:name, max: 255)
    |> validate_length(:url, max: 2048)
    |> validate_format(:url, ~r/^https?:\/\//, message: "must start with http:// or https://")
    |> validate_inclusion(:method, @method_values)
    |> validate_number(:interval_seconds,
      greater_than_or_equal_to: @min_interval,
      less_than_or_equal_to: @max_interval
    )
    |> validate_number(:expected_status, greater_than_or_equal_to: 100, less_than: 600)
    |> validate_number(:failure_threshold, greater_than_or_equal_to: 1)
    |> validate_number(:reopen_window_hours, greater_than_or_equal_to: 1)
    |> validate_length(:keyword, max: 255)
  end
end
