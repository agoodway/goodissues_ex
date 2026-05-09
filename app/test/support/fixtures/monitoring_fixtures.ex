defmodule GI.MonitoringFixtures do
  @moduledoc """
  Test helpers for creating monitoring entities (checks, check_results).
  """

  alias GI.Monitoring

  def unique_check_name, do: "check#{System.unique_integer([:positive])}"

  def valid_check_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: unique_check_name(),
      url: "https://example.com/health",
      method: :get,
      interval_seconds: 300,
      expected_status: 200,
      failure_threshold: 1,
      reopen_window_hours: 24
    })
  end

  @doc """
  Creates a check fixture under the given account/project, authored by the given user.
  """
  def check_fixture(account, user, project, attrs \\ %{}) do
    attrs =
      attrs
      |> valid_check_attributes()
      |> Map.put(:project_id, project.id)

    {:ok, check} = Monitoring.create_check(account, user, attrs)
    check
  end

  # ---- Heartbeat fixtures ----

  def unique_heartbeat_name, do: "heartbeat#{System.unique_integer([:positive])}"

  def valid_heartbeat_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: unique_heartbeat_name(),
      interval_seconds: 300,
      grace_seconds: 60,
      failure_threshold: 1,
      reopen_window_hours: 24
    })
  end

  @doc """
  Creates a heartbeat fixture under the given account/project, authored by the given user.
  """
  def heartbeat_fixture(account, user, project, attrs \\ %{}) do
    attrs =
      attrs
      |> valid_heartbeat_attributes()
      |> Map.put(:project_id, project.id)

    {:ok, heartbeat} = Monitoring.create_heartbeat(account, user, attrs)
    heartbeat
  end
end
