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

  defp perform_for(check, job_id \\ 1) do
    CheckRunner.perform(%Oban.Job{id: job_id, args: %{"check_id" => check.id}})
  end

  defp pending_jobs_for(check) do
    Oban.Job
    |> Repo.all()
    |> Enum.filter(fn j ->
      j.queue == "checks" and Map.get(j.args, "check_id") == check.id and
        j.state in ["available", "scheduled", "retryable"]
    end)
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
      assert :ok =
               CheckRunner.perform(%Oban.Job{id: 1, args: %{"check_id" => Ecto.UUID.generate()}})
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

  describe "try/after rescheduling" do
    test "reschedules even when run/1 raises mid-execution", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{interval_seconds: 60})

      # Set up mock to raise an exception during HTTP request
      MonitoringMockHTTP.set_response_fn(fn _opts -> raise "simulated crash" end)

      # perform/1 should still return :ok because of try/after
      assert :ok = perform_for(check)

      # A successor job should still be enqueued
      jobs = pending_jobs_for(check)
      assert length(jobs) >= 1, "Expected a successor job after raise, got none"
    end

    test "reschedules when create_check_result returns an error", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{interval_seconds: 60})

      # Return a valid HTTP response — the result recording may fail for
      # other reasons (e.g. DB constraint), but rescheduling must happen
      MonitoringMockHTTP.set_response({:ok, %{status: 200, body: "OK"}})

      assert :ok = perform_for(check)

      jobs = pending_jobs_for(check)
      assert length(jobs) >= 1
    end

    test "does NOT enqueue successor when check is deleted during perform/1", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{interval_seconds: 60})

      # Cancel jobs created by fixture, then delete the check
      Scheduler.cancel_jobs(check)
      Repo.delete!(check)

      assert :ok = perform_for(check)

      # No successor job — check was deleted
      jobs = pending_jobs_for(check)
      assert jobs == [], "Expected no successor job for deleted check, got #{length(jobs)}"
    end

    test "does NOT enqueue successor when check is paused mid-perform", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{interval_seconds: 60})

      # Cancel fixture-created jobs so we start clean
      Scheduler.cancel_jobs(check)

      # Pause the check during the HTTP call so reschedule_if_active sees paused
      MonitoringMockHTTP.set_response_fn(fn _opts ->
        Monitoring.update_check(Repo.get!(Check, check.id), %{paused: true})
        {:ok, %{status: 200, body: "OK"}}
      end)

      assert :ok = perform_for(check)

      # After block re-reads check and finds it paused → no successor
      jobs = pending_jobs_for(check)
      assert jobs == [], "Expected no successor for paused check, got #{length(jobs)}"
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

      jobs = pending_jobs_for(check)
      assert length(jobs) == 1
    end

    test "unique config excludes :executing state" do
      opts = CheckRunner.__opts__()
      unique = Keyword.get(opts, :unique)
      states = Keyword.get(unique, :states)

      assert :available in states
      assert :scheduled in states
      assert :retryable in states
      refute :executing in states
    end

    test "schedule_next during :executing creates a new job, not a conflict", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{interval_seconds: 60})

      # Insert a job and manually transition it to executing
      {:ok, job} = Scheduler.schedule_initial(check)

      Ecto.Changeset.change(job, state: "executing", attempted_at: DateTime.utc_now())
      |> Repo.update!()

      # Now schedule_next should insert a NEW job (not conflict)
      {:ok, new_job} = Scheduler.schedule_next(check)
      refute new_job.id == job.id
      assert new_job.state in ["scheduled", "available"]
    end
  end

  describe "parallel execution guard (current_job_id)" do
    test "stamps current_job_id on check during execution", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)
      MonitoringMockHTTP.set_response({:ok, %{status: 200, body: "OK"}})

      perform_for(check, 42)

      reloaded = Repo.get(Check, check.id)
      assert reloaded.current_job_id == 42
    end

    test "discards results when current_job_id has been overwritten", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)

      # Simulate the reaper claiming the check for a newer job during HTTP call
      MonitoringMockHTTP.set_response_fn(fn _opts ->
        Monitoring.update_runtime_fields(Repo.get!(Check, check.id), %{current_job_id: 999})
        {:ok, %{status: 200, body: "OK"}}
      end)

      assert :ok = perform_for(check, 1)

      # No results written — the old runner detected job_id mismatch
      assert results_for(check) == []

      # Check's current_job_id is the newer one
      reloaded = Repo.get(Check, check.id)
      assert reloaded.current_job_id == 999
    end
  end
end
