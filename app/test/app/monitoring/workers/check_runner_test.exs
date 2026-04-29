defmodule FF.Monitoring.Workers.CheckRunnerTest do
  use FF.DataCase, async: false

  import FF.AccountsFixtures
  import FF.MonitoringFixtures
  import FF.TrackingFixtures

  alias FF.Monitoring
  alias FF.Monitoring.Check
  alias FF.Monitoring.Scheduler
  alias FF.Monitoring.Workers.CheckRunner
  alias FF.MonitoringMockHTTP
  alias FF.Repo

  setup do
    {user, account} = user_with_account_fixture()
    project = project_fixture(account)

    prev = Application.get_env(:app, CheckRunner, [])
    Application.put_env(:app, CheckRunner, http_client: MonitoringMockHTTP, timeout_ms: 1000)

    on_exit(fn ->
      Application.put_env(:app, CheckRunner, prev)
      MonitoringMockHTTP.reset()
    end)

    {:ok, user: user, account: account, project: project}
  end

  defp perform_for(check) do
    CheckRunner.perform(%Oban.Job{args: %{"check_id" => check.id}})
  end

  defp results_for(check) do
    Repo.preload(check, :results, force: true).results
  end

  describe "successful check" do
    test "records :up result and resets failure counter", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{expected_status: 200})

      MonitoringMockHTTP.set_response({:ok, %{status: 200, body: "OK"}})

      assert :ok = perform_for(check)

      reloaded = Repo.get(Check, check.id)
      assert reloaded.status == :up
      assert reloaded.consecutive_failures == 0
      assert reloaded.last_checked_at != nil

      [result] = results_for(check)
      assert result.status == :up
      assert result.status_code == 200
      assert result.error == nil
    end
  end

  describe "wrong status code" do
    test "records :down with the actual status and increments failures", %{
      user: user,
      account: account,
      project: project
    } do
      check =
        check_fixture(account, user, project, %{
          expected_status: 200,
          failure_threshold: 5,
          consecutive_failures: 0
        })

      Monitoring.update_runtime_fields(check, %{consecutive_failures: 1})
      check = Repo.get(Check, check.id)

      MonitoringMockHTTP.set_response({:ok, %{status: 500, body: "boom"}})

      assert :ok = perform_for(check)

      reloaded = Repo.get(Check, check.id)
      assert reloaded.consecutive_failures == 2

      [result] = results_for(check)
      assert result.status == :down
      assert result.status_code == 500
      assert result.error =~ "expected status 200"
    end
  end

  describe "connection error" do
    test "records :down with nil status and the error reason", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)

      MonitoringMockHTTP.set_response({:error, :timeout})

      assert :ok = perform_for(check)

      [result] = results_for(check)
      assert result.status == :down
      assert result.status_code == nil
      assert result.error =~ "timeout"
    end
  end

  describe "keyword presence" do
    test "passes when keyword is present and keyword_absence is false", %{
      user: user,
      account: account,
      project: project
    } do
      check =
        check_fixture(account, user, project, %{keyword: "OK", keyword_absence: false})

      MonitoringMockHTTP.set_response({:ok, %{status: 200, body: "Status: OK"}})

      assert :ok = perform_for(check)
      [result] = results_for(check)
      assert result.status == :up
    end

    test "fails when keyword absent and keyword_absence is false", %{
      user: user,
      account: account,
      project: project
    } do
      check =
        check_fixture(account, user, project, %{keyword: "OK", keyword_absence: false})

      MonitoringMockHTTP.set_response({:ok, %{status: 200, body: "no good"}})

      assert :ok = perform_for(check)
      [result] = results_for(check)
      assert result.status == :down
      assert result.error =~ "keyword not found"
    end

    test "fails when keyword present and keyword_absence is true", %{
      user: user,
      account: account,
      project: project
    } do
      check =
        check_fixture(account, user, project, %{keyword: "error", keyword_absence: true})

      MonitoringMockHTTP.set_response({:ok, %{status: 200, body: "fatal error"}})

      assert :ok = perform_for(check)
      [result] = results_for(check)
      assert result.status == :down
      assert result.error =~ "keyword present"
    end

    test "passes when keyword absent and keyword_absence is true", %{
      user: user,
      account: account,
      project: project
    } do
      check =
        check_fixture(account, user, project, %{keyword: "error", keyword_absence: true})

      MonitoringMockHTTP.set_response({:ok, %{status: 200, body: "all good"}})

      assert :ok = perform_for(check)
      [result] = results_for(check)
      assert result.status == :up
    end
  end

  describe "paused check" do
    test "skips execution and records no result", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{paused: true})

      assert :ok = perform_for(check)

      assert results_for(check) == []
    end
  end

  describe "missing check" do
    test "no-ops when check has been deleted" do
      assert :ok = CheckRunner.perform(%Oban.Job{args: %{"check_id" => Ecto.UUID.generate()}})
    end
  end

  describe "rescheduling" do
    test "schedules the next run after a successful execution", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{interval_seconds: 60})

      MonitoringMockHTTP.set_response({:ok, %{status: 200, body: "OK"}})

      assert :ok = perform_for(check)

      jobs =
        Oban.Job
        |> Repo.all()
        |> Enum.filter(fn j ->
          j.queue == "checks" and Map.get(j.args, "check_id") == check.id
        end)

      assert Enum.any?(jobs, fn j -> j.state in ["scheduled", "available"] end)
    end

    test "does not schedule the next run when paused", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{paused: true})

      assert :ok = perform_for(check)

      jobs =
        Oban.Job
        |> Repo.all()
        |> Enum.filter(fn j ->
          j.queue == "checks" and Map.get(j.args, "check_id") == check.id
        end)

      refute Enum.any?(jobs, fn j -> j.state in ["scheduled", "available"] end)
    end
  end

  describe "unique constraint on jobs" do
    test "duplicate enqueues collapse into a single pending job", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)

      assert {:ok, %Oban.Job{}} = Scheduler.schedule_initial(check)
      assert {:ok, %Oban.Job{}} = Scheduler.schedule_initial(check)

      jobs =
        Oban.Job
        |> Repo.all()
        |> Enum.filter(fn j ->
          j.queue == "checks" and Map.get(j.args, "check_id") == check.id and
            j.state in ["available", "scheduled", "retryable"]
        end)

      assert length(jobs) == 1
    end
  end
end
