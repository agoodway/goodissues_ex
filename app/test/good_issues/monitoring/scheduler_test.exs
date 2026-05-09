defmodule FF.Monitoring.SchedulerTest do
  use FF.DataCase, async: false

  import FF.AccountsFixtures
  import FF.MonitoringFixtures
  import FF.TrackingFixtures

  alias FF.Monitoring.Scheduler
  alias FF.Repo

  setup do
    {user, account} = user_with_account_fixture()
    project = project_fixture(account)
    {:ok, user: user, account: account, project: project}
  end

  describe "stuck_executing_jobs/1" do
    test "returns nothing for a freshly executing job", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{interval_seconds: 60})
      {:ok, job} = Scheduler.schedule_initial(check)

      # Transition to executing with a recent attempted_at
      now = DateTime.utc_now()

      Ecto.Changeset.change(job, state: "executing", attempted_at: now)
      |> Repo.update!()

      assert Scheduler.stuck_executing_jobs(now) == []
    end

    test "returns jobs past the stuck threshold", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{interval_seconds: 60})
      {:ok, job} = Scheduler.schedule_initial(check)

      now = DateTime.utc_now()
      # 5 * 60 = 300 seconds threshold; set attempted_at 301s ago
      old_attempted = DateTime.add(now, -301, :second)

      Ecto.Changeset.change(job, state: "executing", attempted_at: old_attempted)
      |> Repo.update!()

      results = Scheduler.stuck_executing_jobs(now)
      assert length(results) == 1
      [{stuck_job, stuck_check}] = results
      assert stuck_job.id == job.id
      assert stuck_check.id == check.id
    end

    test "does not return job at exactly the threshold boundary", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{interval_seconds: 60})
      {:ok, job} = Scheduler.schedule_initial(check)

      now = DateTime.utc_now()
      # Exactly at threshold: 300s ago (5 * 60). Uses strict <, so not stuck.
      at_threshold = DateTime.add(now, -300, :second)

      Ecto.Changeset.change(job, state: "executing", attempted_at: at_threshold)
      |> Repo.update!()

      assert Scheduler.stuck_executing_jobs(now) == []
    end

    test "does not return job just before the threshold", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{interval_seconds: 60})
      {:ok, job} = Scheduler.schedule_initial(check)

      now = DateTime.utc_now()
      # 1 second before threshold
      before_threshold = DateTime.add(now, -299, :second)

      Ecto.Changeset.change(job, state: "executing", attempted_at: before_threshold)
      |> Repo.update!()

      assert Scheduler.stuck_executing_jobs(now) == []
    end

    test "returns multiple stuck jobs from distinct checks", %{
      user: user,
      account: account,
      project: project
    } do
      check1 = check_fixture(account, user, project, %{interval_seconds: 60, name: "Check A"})
      check2 = check_fixture(account, user, project, %{interval_seconds: 60, name: "Check B"})

      {:ok, job1} = Scheduler.schedule_initial(check1)
      {:ok, job2} = Scheduler.schedule_initial(check2)

      now = DateTime.utc_now()
      old_attempted = DateTime.add(now, -301, :second)

      Ecto.Changeset.change(job1, state: "executing", attempted_at: old_attempted)
      |> Repo.update!()

      Ecto.Changeset.change(job2, state: "executing", attempted_at: old_attempted)
      |> Repo.update!()

      results = Scheduler.stuck_executing_jobs(now)
      assert length(results) == 2

      returned_check_ids = Enum.map(results, fn {_job, check} -> check.id end) |> Enum.sort()
      expected = Enum.sort([check1.id, check2.id])
      assert returned_check_ids == expected
    end

    test "excludes paused checks", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{interval_seconds: 60})
      {:ok, job} = Scheduler.schedule_initial(check)

      now = DateTime.utc_now()
      old_attempted = DateTime.add(now, -301, :second)

      Ecto.Changeset.change(job, state: "executing", attempted_at: old_attempted)
      |> Repo.update!()

      # Pause the check
      FF.Monitoring.update_check(check, %{paused: true})

      assert Scheduler.stuck_executing_jobs(now) == []
    end
  end

  describe "cancel_job/2" do
    test "transitions a single job to cancelled when check_id matches", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)
      {:ok, job} = Scheduler.schedule_initial(check)

      assert {:ok, 1} = Scheduler.cancel_job(job, check)

      reloaded = Repo.get(Oban.Job, job.id)
      assert reloaded.state == "cancelled"
    end

    test "does not cancel job when check_id does not match", %{
      user: user,
      account: account,
      project: project
    } do
      check1 = check_fixture(account, user, project, %{name: "Check A"})
      check2 = check_fixture(account, user, project, %{name: "Check B"})
      {:ok, job} = Scheduler.schedule_initial(check1)

      # Try to cancel check1's job using check2 — should not match
      assert {:ok, 0} = Scheduler.cancel_job(job, check2)

      reloaded = Repo.get(Oban.Job, job.id)
      refute reloaded.state == "cancelled"
    end

    test "returns {:ok, 0} for nonexistent job ID", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)
      fake_job = %Oban.Job{id: 999_999_999}

      assert {:ok, 0} = Scheduler.cancel_job(fake_job, check)
    end
  end
end
