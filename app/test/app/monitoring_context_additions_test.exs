defmodule FF.MonitoringContextAdditionsTest do
  use FF.DataCase, async: false

  import FF.AccountsFixtures
  import FF.MonitoringFixtures
  import FF.TrackingFixtures

  alias FF.Monitoring

  setup do
    {user, account} = user_with_account_fixture()
    project = project_fixture(account)
    {:ok, user: user, account: account, project: project}
  end

  describe "count_checks_by_status/2" do
    test "returns zeros when no checks exist", %{account: account, project: project} do
      assert Monitoring.count_checks_by_status(account, project.id) == %{
               up: 0,
               down: 0,
               unknown: 0,
               paused: 0
             }
    end

    test "counts checks by status", %{user: user, account: account, project: project} do
      # Create checks in various states
      _unknown = check_fixture(account, user, project, %{name: "C1"})
      paused = check_fixture(account, user, project, %{name: "C2"})
      up_check = check_fixture(account, user, project, %{name: "C3"})

      # Set states via runtime updates
      Monitoring.update_check(paused, %{paused: true})
      Monitoring.update_runtime_fields(up_check, %{status: :up})

      result = Monitoring.count_checks_by_status(account, project.id)
      assert result.unknown == 1
      assert result.paused == 1
      assert result.up == 1
      assert result.down == 0
    end

    test "paused checks count as paused regardless of status", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)
      Monitoring.update_runtime_fields(check, %{status: :up})
      Monitoring.update_check(check, %{paused: true})

      result = Monitoring.count_checks_by_status(account, project.id)
      assert result.paused == 1
      assert result.up == 0
    end
  end

  describe "list_check_results/4 with status filter" do
    test "filters results by status", %{user: user, account: account, project: project} do
      check = check_fixture(account, user, project)

      # Create some results
      Monitoring.create_check_result(check, %{
        status: :up,
        status_code: 200,
        response_ms: 100,
        checked_at: DateTime.utc_now(:second)
      })

      Monitoring.create_check_result(check, %{
        status: :down,
        status_code: 500,
        response_ms: 200,
        error: "server error",
        checked_at: DateTime.utc_now(:second)
      })

      Monitoring.create_check_result(check, %{
        status: :up,
        status_code: 200,
        response_ms: 150,
        checked_at: DateTime.utc_now(:second)
      })

      # No filter - all results
      all = Monitoring.list_check_results(account, project.id, check.id, %{})
      assert all.total == 3

      # Filter by :up
      up_only = Monitoring.list_check_results(account, project.id, check.id, %{status: :up})
      assert up_only.total == 2
      assert Enum.all?(up_only.results, &(&1.status == :up))

      # Filter by :down
      down_only = Monitoring.list_check_results(account, project.id, check.id, %{status: :down})
      assert down_only.total == 1
      assert Enum.all?(down_only.results, &(&1.status == :down))

      # String filter
      string_filter =
        Monitoring.list_check_results(account, project.id, check.id, %{"status" => "down"})

      assert string_filter.total == 1
    end
  end
end
