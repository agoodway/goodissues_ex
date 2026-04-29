defmodule FF.MonitoringFixtures do
  @moduledoc """
  Test helpers for creating monitoring entities (checks, check_results).
  """

  alias FF.Monitoring

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
end
