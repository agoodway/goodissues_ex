defmodule FF.Monitoring.Workers.HeartbeatRecoveryTest do
  use FF.DataCase, async: false

  import FF.AccountsFixtures
  import FF.MonitoringFixtures
  import FF.TrackingFixtures

  alias FF.Monitoring
  alias FF.Monitoring.Heartbeat
  alias FF.Monitoring.Workers.HeartbeatRecovery
  alias FF.Repo

  setup do
    {user, account} = user_with_account_fixture()
    project = project_fixture(account)
    {:ok, user: user, account: account, project: project}
  end

  test "perform/1 completes successfully with no orphans or stuck jobs", %{
    user: user,
    account: account,
    project: project
  } do
    _hb = heartbeat_fixture(account, user, project, %{paused: true})

    job = %Oban.Job{args: %{}}
    assert :ok = HeartbeatRecovery.perform(job)
  end

  test "emits telemetry on run", %{user: user, account: account, project: project} do
    _hb = heartbeat_fixture(account, user, project, %{paused: true})

    ref =
      :telemetry_test.attach_event_handlers(self(), [
        [:ff, :monitoring, :heartbeat_reaper, :run]
      ])

    job = %Oban.Job{args: %{}}
    HeartbeatRecovery.perform(job)

    assert_receive {[:ff, :monitoring, :heartbeat_reaper, :run], ^ref, measurements, _meta}
    assert is_integer(measurements.orphan_count)
    assert is_integer(measurements.stuck_count)
  end

  test "recovers orphaned heartbeats", %{user: user, account: account, project: project} do
    hb = heartbeat_fixture(account, user, project, %{paused: true})
    {:ok, _} = Monitoring.update_heartbeat(hb, %{paused: false})
    hb = Repo.get!(Heartbeat, hb.id)

    # Cancel all jobs to make it orphaned
    FF.Monitoring.HeartbeatScheduler.cancel_deadline(hb)

    ref =
      :telemetry_test.attach_event_handlers(self(), [
        [:ff, :monitoring, :heartbeat_reaper, :run],
        [:ff, :monitoring, :heartbeat_reaper, :recovered]
      ])

    job = %Oban.Job{args: %{}}
    HeartbeatRecovery.perform(job)

    assert_receive {[:ff, :monitoring, :heartbeat_reaper, :run], ^ref, %{orphan_count: count}, _}
    assert count >= 1
  end
end
