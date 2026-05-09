defmodule FF.Monitoring.JobLifecycleTest do
  use FF.DataCase, async: false

  import FF.AccountsFixtures
  import FF.MonitoringFixtures
  import FF.TrackingFixtures

  alias FF.Monitoring
  alias FF.Monitoring.Scheduler
  alias FF.Repo

  setup do
    {user, account} = user_with_account_fixture()
    project = project_fixture(account)
    {:ok, user: user, account: account, project: project}
  end

  defp pending_jobs_for(check_id) do
    import Ecto.Query

    from(j in Oban.Job,
      where: j.queue == "checks",
      where: j.state in ["available", "scheduled", "retryable"],
      where: fragment("?->>'check_id' = ?", j.args, ^check_id)
    )
    |> Repo.all()
  end

  describe "create_check enqueues the first job" do
    test "inserts a checks-queue job when not paused", %{
      user: user,
      account: account,
      project: project
    } do
      attrs = %{
        name: "Lifecycle",
        url: "https://example.com",
        project_id: project.id,
        paused: false
      }

      assert {:ok, check} = Monitoring.create_check(account, user, attrs)
      assert [_job] = pending_jobs_for(check.id)
    end

    test "no job when paused", %{user: user, account: account, project: project} do
      check = check_fixture(account, user, project, %{paused: true})
      assert pending_jobs_for(check.id) == []
    end
  end

  describe "update_check resumes a paused check" do
    test "enqueues a job when paused -> not paused", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{paused: true})
      assert pending_jobs_for(check.id) == []

      assert {:ok, _} = Monitoring.update_check(check, %{paused: false})
      assert [_job] = pending_jobs_for(check.id)
    end

    test "does not re-enqueue when already running", %{
      user: user,
      account: account,
      project: project
    } do
      attrs = %{
        name: "running",
        url: "https://example.com",
        project_id: project.id,
        paused: false
      }

      {:ok, check} = Monitoring.create_check(account, user, attrs)
      assert length(pending_jobs_for(check.id)) == 1

      {:ok, _} = Monitoring.update_check(check, %{interval_seconds: 120})
      assert length(pending_jobs_for(check.id)) == 1
    end
  end

  describe "delete_check cancels pending jobs" do
    test "all pending jobs become cancelled", %{
      user: user,
      account: account,
      project: project
    } do
      attrs = %{
        name: "doomed",
        url: "https://example.com",
        project_id: project.id,
        paused: false
      }

      {:ok, check} = Monitoring.create_check(account, user, attrs)
      assert length(pending_jobs_for(check.id)) == 1

      {:ok, _} = Monitoring.delete_check(check)
      assert pending_jobs_for(check.id) == []
    end
  end

  describe "Scheduler.recover_orphaned_jobs/0" do
    test "re-enqueues active checks with no pending job", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{paused: false})

      # Wipe any pending jobs to simulate post-restart drift.
      Scheduler.cancel_jobs(check)
      assert pending_jobs_for(check.id) == []

      Scheduler.recover_orphaned_jobs()
      assert [_job] = pending_jobs_for(check.id)
    end

    test "does not enqueue paused checks", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{paused: true})

      Scheduler.recover_orphaned_jobs()
      assert pending_jobs_for(check.id) == []
    end
  end
end
