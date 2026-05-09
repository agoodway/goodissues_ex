defmodule GI.MonitoringTest do
  use GI.DataCase, async: false

  import GI.AccountsFixtures
  import GI.MonitoringFixtures
  import GI.TrackingFixtures

  alias GI.Monitoring
  alias GI.Monitoring.{Check, CheckResult}

  setup do
    {user, account} = user_with_account_fixture()
    project = project_fixture(account)
    {:ok, user: user, account: account, project: project}
  end

  describe "create_check/3" do
    test "creates a check with defaults", %{user: user, account: account, project: project} do
      attrs = %{
        name: "API Health",
        url: "https://api.example.com/health",
        project_id: project.id
      }

      assert {:ok, %Check{} = check} = Monitoring.create_check(account, user, attrs)
      assert check.name == "API Health"
      assert check.url == "https://api.example.com/health"
      assert check.method == :get
      assert check.expected_status == 200
      assert check.interval_seconds == 300
      assert check.failure_threshold == 1
      assert check.reopen_window_hours == 24
      assert check.paused == false
      assert check.status == :unknown
      assert check.created_by_id == user.id
      assert check.project_id == project.id
    end

    test "rejects checks for projects in other accounts", %{user: user} do
      {other_user, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)
      {_, account} = user_with_account_fixture(%{user: %{}})

      attrs = %{
        name: "Boundary",
        url: "https://example.com",
        project_id: other_project.id
      }

      assert {:error, changeset} = Monitoring.create_check(account, user, attrs)

      assert "does not exist or belongs to another account" in errors_on(changeset).project_id

      _ = other_user
    end

    test "validates url format", %{user: user, account: account, project: project} do
      attrs = %{name: "Bad", url: "not-a-url", project_id: project.id}
      assert {:error, changeset} = Monitoring.create_check(account, user, attrs)
      assert "must start with http:// or https://" in errors_on(changeset).url
    end

    test "validates interval bounds", %{user: user, account: account, project: project} do
      too_low = %{
        name: "Low",
        url: "https://example.com",
        interval_seconds: 10,
        project_id: project.id
      }

      too_high = %{
        name: "High",
        url: "https://example.com",
        interval_seconds: 7200,
        project_id: project.id
      }

      assert {:error, low_changeset} = Monitoring.create_check(account, user, too_low)
      assert {:error, high_changeset} = Monitoring.create_check(account, user, too_high)
      assert errors_on(low_changeset).interval_seconds != []
      assert errors_on(high_changeset).interval_seconds != []
    end

    test "stores keyword and keyword_absence", %{user: user, account: account, project: project} do
      attrs = %{
        name: "K",
        url: "https://example.com",
        keyword: "OK",
        keyword_absence: false,
        project_id: project.id
      }

      assert {:ok, check} = Monitoring.create_check(account, user, attrs)
      assert check.keyword == "OK"
      assert check.keyword_absence == false
    end
  end

  describe "get_check/3 and get_check!/3" do
    test "returns a check belonging to the project", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)
      assert %Check{id: id} = Monitoring.get_check(account, project.id, check.id)
      assert id == check.id
    end

    test "returns nil when check belongs to another project", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)
      other_project = project_fixture(account)
      assert Monitoring.get_check(account, other_project.id, check.id) == nil
    end

    test "returns nil for invalid uuids", %{account: account, project: project} do
      assert Monitoring.get_check(account, "nope", "nope") == nil
      assert Monitoring.get_check(account, project.id, "nope") == nil
    end

    test "get_check!/3 raises when not found", %{account: account, project: project} do
      assert_raise Ecto.NoResultsError, fn ->
        Monitoring.get_check!(account, project.id, Ecto.UUID.generate())
      end
    end
  end

  describe "list_checks/3" do
    test "lists checks with pagination meta", %{
      user: user,
      account: account,
      project: project
    } do
      _c1 = check_fixture(account, user, project, %{name: "alpha"})
      _c2 = check_fixture(account, user, project, %{name: "beta"})

      assert %{checks: [a, b], total: 2, total_pages: 1, page: 1} =
               Monitoring.list_checks(account, project.id)

      assert a.name == "alpha"
      assert b.name == "beta"
    end

    test "respects per_page", %{user: user, account: account, project: project} do
      for i <- 1..3 do
        check_fixture(account, user, project, %{name: "c#{i}"})
      end

      assert %{checks: [_], page: 1, per_page: 1, total: 3, total_pages: 3} =
               Monitoring.list_checks(account, project.id, %{per_page: 1})
    end

    test "returns empty when project not in account", %{} do
      {other_user, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)

      {_, account} = user_with_account_fixture()

      assert %{checks: [], total: 0} = Monitoring.list_checks(account, other_project.id)
      _ = other_user
    end
  end

  describe "update_check/2" do
    test "updates fields", %{user: user, account: account, project: project} do
      check = check_fixture(account, user, project, %{interval_seconds: 60})

      assert {:ok, updated} =
               Monitoring.update_check(check, %{
                 name: "renamed",
                 interval_seconds: 120
               })

      assert updated.name == "renamed"
      assert updated.interval_seconds == 120
    end

    test "rejects invalid url", %{user: user, account: account, project: project} do
      check = check_fixture(account, user, project)
      assert {:error, changeset} = Monitoring.update_check(check, %{url: "ftp://nope"})
      assert "must start with http:// or https://" in errors_on(changeset).url
    end
  end

  describe "delete_check/1" do
    test "removes the check", %{user: user, account: account, project: project} do
      check = check_fixture(account, user, project)
      assert {:ok, _} = Monitoring.delete_check(check)
      assert Monitoring.get_check(account, project.id, check.id) == nil
    end
  end

  describe "create_check_result/2" do
    test "stores a result and exposes it via list_check_results", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)

      assert {:ok, %CheckResult{}} =
               Monitoring.create_check_result(check, %{
                 status: :up,
                 status_code: 200,
                 response_ms: 50
               })

      result = Monitoring.list_check_results(account, project.id, check.id)
      assert result.total == 1
      assert [%CheckResult{status: :up, status_code: 200}] = result.results
    end

    test "results listed in reverse chronological order", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)

      now = DateTime.utc_now(:second)

      {:ok, _} =
        Monitoring.create_check_result(check, %{
          status: :up,
          status_code: 200,
          response_ms: 10,
          checked_at: DateTime.add(now, -120, :second)
        })

      {:ok, _} =
        Monitoring.create_check_result(check, %{
          status: :down,
          status_code: 500,
          response_ms: 20,
          error: "boom",
          checked_at: now
        })

      assert %{results: [first, second]} =
               Monitoring.list_check_results(account, project.id, check.id)

      assert first.status == :down
      assert second.status == :up
    end

    test "list_check_results returns nil when check not visible", %{
      account: account,
      project: project
    } do
      assert Monitoring.list_check_results(account, project.id, Ecto.UUID.generate()) == nil
    end
  end

  describe "find_incident_issue/2" do
    test "returns :none when check has never had an incident", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)
      assert Monitoring.find_incident_issue(check) == :none
    end

    test "returns {:open, issue} when current_issue_id points to open issue", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)
      issue = issue_fixture(account, user, project, %{type: :incident})

      {:ok, check} =
        Monitoring.update_runtime_fields(check, %{current_issue_id: issue.id, status: :down})

      assert {:open, %{id: open_id}} = Monitoring.find_incident_issue(check)
      assert open_id == issue.id
    end

    test "returns {:reopen, issue} when most recent result references archived issue within window",
         %{user: user, account: account, project: project} do
      check = check_fixture(account, user, project, %{reopen_window_hours: 24})
      issue = issue_fixture(account, user, project, %{type: :incident, status: :archived})

      {:ok, _} =
        Monitoring.create_check_result(check, %{
          status: :down,
          status_code: 500,
          response_ms: 1,
          error: "x",
          issue_id: issue.id
        })

      assert {:reopen, %{id: reopen_id}} = Monitoring.find_incident_issue(check)
      assert reopen_id == issue.id
    end

    test "returns :none when archived issue is older than window", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{reopen_window_hours: 1})
      issue = issue_fixture(account, user, project, %{type: :incident, status: :archived})

      old_archived_at = DateTime.add(DateTime.utc_now(:second), -7200, :second)

      issue
      |> Ecto.Changeset.change(archived_at: old_archived_at)
      |> GI.Repo.update!()

      {:ok, _} =
        Monitoring.create_check_result(check, %{
          status: :down,
          status_code: 500,
          response_ms: 1,
          issue_id: issue.id
        })

      assert Monitoring.find_incident_issue(check) == :none
    end
  end
end
