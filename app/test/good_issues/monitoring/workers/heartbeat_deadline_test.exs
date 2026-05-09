defmodule GI.Monitoring.Workers.HeartbeatDeadlineTest do
  use GI.DataCase, async: false

  import GI.AccountsFixtures
  import GI.MonitoringFixtures
  import GI.TrackingFixtures

  alias GI.Monitoring
  alias GI.Monitoring.Heartbeat
  alias GI.Monitoring.Workers.HeartbeatDeadline
  alias GI.Repo

  setup do
    {user, account} = user_with_account_fixture()
    project = project_fixture(account)
    {:ok, user: user, account: account, project: project}
  end

  test "increments failures on deadline fire", %{user: user, account: account, project: project} do
    hb = heartbeat_fixture(account, user, project, %{paused: true, failure_threshold: 3})
    {:ok, _} = Monitoring.update_heartbeat(hb, %{paused: false})
    hb = Repo.get!(Heartbeat, hb.id)

    job = %Oban.Job{
      args: %{"heartbeat_id" => hb.id, "scheduled_for" => DateTime.to_iso8601(hb.next_due_at)}
    }

    assert :ok = HeartbeatDeadline.perform(job)

    updated = Repo.get!(Heartbeat, hb.id)
    assert updated.consecutive_failures == 1
    assert updated.started_at == nil
    # Still below threshold
    assert updated.status == :unknown
  end

  test "sets status to down when threshold reached", %{
    user: user,
    account: account,
    project: project
  } do
    hb = heartbeat_fixture(account, user, project, %{paused: true, failure_threshold: 1})
    {:ok, _} = Monitoring.update_heartbeat(hb, %{paused: false})
    hb = Repo.get!(Heartbeat, hb.id)

    job = %Oban.Job{
      args: %{"heartbeat_id" => hb.id, "scheduled_for" => DateTime.to_iso8601(hb.next_due_at)}
    }

    assert :ok = HeartbeatDeadline.perform(job)

    updated = Repo.get!(Heartbeat, hb.id)
    assert updated.consecutive_failures == 1
    assert updated.status == :down
  end

  test "stale job does not mutate state", %{user: user, account: account, project: project} do
    hb = heartbeat_fixture(account, user, project, %{paused: true})
    {:ok, _} = Monitoring.update_heartbeat(hb, %{paused: false})
    hb = Repo.get!(Heartbeat, hb.id)

    # Use a stale scheduled_for that doesn't match next_due_at
    stale_time = DateTime.add(hb.next_due_at, -3600, :second)

    job = %Oban.Job{
      args: %{"heartbeat_id" => hb.id, "scheduled_for" => DateTime.to_iso8601(stale_time)}
    }

    assert :ok = HeartbeatDeadline.perform(job)

    updated = Repo.get!(Heartbeat, hb.id)
    assert updated.consecutive_failures == 0
  end

  test "paused heartbeat does not fire", %{user: user, account: account, project: project} do
    hb = heartbeat_fixture(account, user, project, %{paused: true})

    job = %Oban.Job{
      args: %{"heartbeat_id" => hb.id, "scheduled_for" => "2026-01-01T00:00:00Z"}
    }

    assert :ok = HeartbeatDeadline.perform(job)

    updated = Repo.get!(Heartbeat, hb.id)
    assert updated.consecutive_failures == 0
  end

  test "deleted heartbeat no-ops", %{user: user, account: account, project: project} do
    hb = heartbeat_fixture(account, user, project, %{paused: true})
    {:ok, _} = Monitoring.delete_heartbeat(hb)

    job = %Oban.Job{
      args: %{"heartbeat_id" => hb.id, "scheduled_for" => "2026-01-01T00:00:00Z"}
    }

    assert :ok = HeartbeatDeadline.perform(job)
  end

  test "creates incident when threshold is reached", %{
    user: user,
    account: account,
    project: project
  } do
    hb = heartbeat_fixture(account, user, project, %{paused: true, failure_threshold: 1})
    {:ok, _} = Monitoring.update_heartbeat(hb, %{paused: false})
    hb = Repo.get!(Heartbeat, hb.id)

    job = %Oban.Job{
      args: %{"heartbeat_id" => hb.id, "scheduled_for" => DateTime.to_iso8601(hb.next_due_at)}
    }

    assert :ok = HeartbeatDeadline.perform(job)

    updated = Repo.get!(Heartbeat, hb.id)
    assert updated.status == :down
    assert updated.current_issue_id != nil
  end

  test "malformed scheduled_for treated as stale", %{
    user: user,
    account: account,
    project: project
  } do
    hb = heartbeat_fixture(account, user, project, %{paused: true})
    {:ok, _} = Monitoring.update_heartbeat(hb, %{paused: false})
    hb = Repo.get!(Heartbeat, hb.id)

    job = %Oban.Job{
      args: %{"heartbeat_id" => hb.id, "scheduled_for" => "not-a-date"}
    }

    assert :ok = HeartbeatDeadline.perform(job)

    updated = Repo.get!(Heartbeat, hb.id)
    assert updated.consecutive_failures == 0
  end

  test "advances next_due_at from prior due time", %{
    user: user,
    account: account,
    project: project
  } do
    hb =
      heartbeat_fixture(account, user, project, %{
        paused: true,
        interval_seconds: 300,
        grace_seconds: 60,
        failure_threshold: 5
      })

    {:ok, _} = Monitoring.update_heartbeat(hb, %{paused: false})
    hb = Repo.get!(Heartbeat, hb.id)

    original_due = hb.next_due_at

    job = %Oban.Job{
      args: %{"heartbeat_id" => hb.id, "scheduled_for" => DateTime.to_iso8601(hb.next_due_at)}
    }

    HeartbeatDeadline.perform(job)

    updated = Repo.get!(Heartbeat, hb.id)
    expected_due = DateTime.add(original_due, 300 + 60, :second)

    assert DateTime.truncate(updated.next_due_at, :second) ==
             DateTime.truncate(expected_due, :second)
  end
end
