defmodule FF.Monitoring.Workers.ReaperTest do
  use FF.DataCase, async: false

  import FF.AccountsFixtures
  import FF.MonitoringFixtures
  import FF.TrackingFixtures

  alias FF.Monitoring
  alias FF.Monitoring.Scheduler
  alias FF.Monitoring.Workers.Reaper
  alias FF.Repo

  setup do
    {user, account} = user_with_account_fixture()
    project = project_fixture(account)
    {:ok, user: user, account: account, project: project}
  end

  defp perform_reaper do
    Reaper.perform(%Oban.Job{args: %{}})
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

  describe "orphan recovery" do
    test "recovers an orphaned check by scheduling a new job", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{paused: false})

      # Cancel all jobs to create an orphan
      Scheduler.cancel_jobs(check)
      assert pending_jobs_for(check.id) == []

      assert :ok = perform_reaper()

      # Reaper should have re-enqueued a job
      assert [_job] = pending_jobs_for(check.id)
    end
  end

  describe "stuck recovery" do
    test "cancels stuck job and reschedules", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{interval_seconds: 60})

      # Get the existing job and make it stuck
      [job] = pending_jobs_for(check.id)

      old_attempted = DateTime.add(DateTime.utc_now(), -301, :second)

      Ecto.Changeset.change(job, state: "executing", attempted_at: old_attempted)
      |> Repo.update!()

      assert pending_jobs_for(check.id) == []

      assert :ok = perform_reaper()

      # Old job should be cancelled
      reloaded_job = Repo.get(Oban.Job, job.id)
      assert reloaded_job.state == "cancelled"

      # A new job should be scheduled
      assert [new_job] = pending_jobs_for(check.id)
      assert new_job.id != job.id
    end
  end

  describe "no-op run" do
    test "completes successfully when nothing is broken", %{
      user: user,
      account: account,
      project: project
    } do
      # Create a healthy check with a pending job
      _check = check_fixture(account, user, project, %{paused: false})

      assert :ok = perform_reaper()
    end
  end

  describe "empty database" do
    test "completes successfully with zero checks" do
      assert :ok = perform_reaper()
    end
  end

  describe "combined orphan and stuck recovery" do
    test "recovers both orphans and stuck jobs in a single run", %{
      user: user,
      account: account,
      project: project
    } do
      # Create an orphaned check
      orphan = check_fixture(account, user, project, %{paused: false, name: "Orphan"})
      Scheduler.cancel_jobs(orphan)

      # Create a stuck check
      stuck = check_fixture(account, user, project, %{interval_seconds: 60, name: "Stuck"})
      [job] = pending_jobs_for(stuck.id)
      old_attempted = DateTime.add(DateTime.utc_now(), -301, :second)

      Ecto.Changeset.change(job, state: "executing", attempted_at: old_attempted)
      |> Repo.update!()

      Phoenix.PubSub.subscribe(FF.PubSub, Monitoring.reaper_topic())

      assert :ok = perform_reaper()

      # Both recovered
      assert [_] = pending_jobs_for(orphan.id)
      assert [_] = pending_jobs_for(stuck.id)

      # PubSub reports aggregate counts
      assert_received {:reaper_run_completed, payload}
      assert payload.count == 2
      assert payload.by_reason.orphaned == 1
      assert payload.by_reason.stuck == 1
    end
  end

  describe "telemetry" do
    test "emits :run and :recovered telemetry for orphan recovery", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{paused: false})
      Scheduler.cancel_jobs(check)

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:ff, :monitoring, :reaper, :run],
          [:ff, :monitoring, :reaper, :recovered]
        ])

      perform_reaper()

      assert_received {[:ff, :monitoring, :reaper, :run], ^ref, measurements, %{}}
      assert measurements.orphan_count == 1
      assert measurements.stuck_count == 0
      assert measurements.recovered_count == 1
      assert is_integer(measurements.duration_ms)

      assert_received {[:ff, :monitoring, :reaper, :recovered], ^ref, %{},
                       %{check_id: _, reason: :orphaned}}
    end

    test "emits :recovered telemetry with reason:stuck for stuck jobs", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{interval_seconds: 60})
      [job] = pending_jobs_for(check.id)

      old_attempted = DateTime.add(DateTime.utc_now(), -301, :second)

      Ecto.Changeset.change(job, state: "executing", attempted_at: old_attempted)
      |> Repo.update!()

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:ff, :monitoring, :reaper, :recovered]
        ])

      perform_reaper()

      assert_received {[:ff, :monitoring, :reaper, :recovered], ^ref, %{},
                       %{check_id: check_id, reason: :stuck}}

      assert check_id == check.id
    end
  end

  describe "PubSub" do
    test "broadcasts reaper_run_completed exactly once per run", %{
      user: user,
      account: account,
      project: project
    } do
      _check = check_fixture(account, user, project, %{paused: false})

      Phoenix.PubSub.subscribe(FF.PubSub, Monitoring.reaper_topic())

      perform_reaper()

      assert_received {:reaper_run_completed, payload}
      assert payload.count == 0
      assert payload.by_reason == %{orphaned: 0, stuck: 0}

      # Only one event
      refute_received {:reaper_run_completed, _}
    end

    test "broadcasts with correct counts when recoveries occur", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{paused: false})
      Scheduler.cancel_jobs(check)

      Phoenix.PubSub.subscribe(FF.PubSub, Monitoring.reaper_topic())

      perform_reaper()

      assert_received {:reaper_run_completed, payload}
      assert payload.count == 1
      assert payload.by_reason.orphaned == 1
    end
  end

  describe "worker opts" do
    test "uses unique constraint to prevent concurrent reaper runs" do
      opts = Reaper.__opts__()
      unique = Keyword.get(opts, :unique)

      assert Keyword.get(unique, :period) == 55
      assert :executing in Keyword.get(unique, :states)
    end

    test "runs on the maintenance queue" do
      opts = Reaper.__opts__()
      assert Keyword.get(opts, :queue) == :maintenance
    end
  end
end
