defmodule FF.Monitoring.HeartbeatIncidentLifecycleTest do
  use FF.DataCase, async: false

  import FF.AccountsFixtures
  import FF.MonitoringFixtures
  import FF.TrackingFixtures

  alias FF.Monitoring
  alias FF.Monitoring.{Heartbeat, HeartbeatIncidentLifecycle}
  alias FF.Repo
  alias FF.Tracking
  alias FF.Tracking.Issue

  setup do
    {user, account} = user_with_account_fixture()
    project = project_fixture(account)
    {:ok, user: user, account: account, project: project}
  end

  describe "create_or_reopen_incident/2" do
    test "creates a new incident when none exists", %{
      user: user,
      account: account,
      project: project
    } do
      hb = heartbeat_fixture(account, user, project, %{paused: true, failure_threshold: 1})
      {:ok, hb} = Monitoring.update_heartbeat(hb, %{paused: false})

      # Force down state
      {:ok, _} =
        Monitoring.update_heartbeat_runtime(hb, %{
          consecutive_failures: 1,
          status: :down
        })

      hb = Repo.get!(Heartbeat, hb.id)

      assert {:ok, %Issue{} = issue} = HeartbeatIncidentLifecycle.create_or_reopen_incident(hb)
      assert issue.type == :incident
      assert issue.title =~ "DOWN:"

      updated = Repo.get!(Heartbeat, hb.id)
      assert updated.current_issue_id == issue.id
    end

    test "no-ops when an open incident already exists", %{
      user: user,
      account: account,
      project: project
    } do
      hb = heartbeat_fixture(account, user, project, %{paused: true, failure_threshold: 1})
      {:ok, hb} = Monitoring.update_heartbeat(hb, %{paused: false})

      {:ok, _} =
        Monitoring.update_heartbeat_runtime(hb, %{
          consecutive_failures: 1,
          status: :down
        })

      hb = Repo.get!(Heartbeat, hb.id)

      {:ok, issue} = HeartbeatIncidentLifecycle.create_or_reopen_incident(hb)
      hb = Repo.get!(Heartbeat, hb.id)

      assert :ok = HeartbeatIncidentLifecycle.create_or_reopen_incident(hb)

      # Incident should still be the same
      updated_hb = Repo.get!(Heartbeat, hb.id)
      assert updated_hb.current_issue_id == issue.id
    end

    test "reopens a recently archived incident", %{
      user: user,
      account: account,
      project: project
    } do
      hb =
        heartbeat_fixture(account, user, project, %{
          paused: true,
          failure_threshold: 1,
          reopen_window_hours: 24
        })

      {:ok, hb} = Monitoring.update_heartbeat(hb, %{paused: false})

      {:ok, _} =
        Monitoring.update_heartbeat_runtime(hb, %{
          consecutive_failures: 1,
          status: :down
        })

      hb = Repo.get!(Heartbeat, hb.id)

      # Create incident then archive it
      {:ok, issue} = HeartbeatIncidentLifecycle.create_or_reopen_incident(hb)
      hb = Repo.get!(Heartbeat, hb.id)
      HeartbeatIncidentLifecycle.handle_recovery(hb)

      # Simulate another failure
      hb = Repo.get!(Heartbeat, hb.id)

      {:ok, _} =
        Monitoring.update_heartbeat_runtime(hb, %{
          consecutive_failures: 1,
          status: :down
        })

      hb = Repo.get!(Heartbeat, hb.id)

      {:ok, reopened} = HeartbeatIncidentLifecycle.create_or_reopen_incident(hb)
      assert reopened.id == issue.id
      assert reopened.status == :in_progress
    end

    test "links ping to incident when provided", %{
      user: user,
      account: account,
      project: project
    } do
      hb = heartbeat_fixture(account, user, project, %{paused: true, failure_threshold: 2})
      {:ok, hb} = Monitoring.update_heartbeat(hb, %{paused: false})

      # First fail — below threshold, no incident yet
      {:ok, _ping} = Monitoring.receive_ping(hb, :fail)
      hb = Repo.get!(Heartbeat, hb.id)

      # Second fail — reaches threshold, incident should be created with ping linked
      {:ok, ping2} = Monitoring.receive_ping(hb, :fail)
      hb = Repo.get!(Heartbeat, hb.id)

      assert hb.current_issue_id != nil

      # The ping should be linked to the incident
      reloaded_ping = Repo.get!(FF.Monitoring.HeartbeatPing, ping2.id)
      assert reloaded_ping.issue_id == hb.current_issue_id
    end
  end

  describe "handle_recovery/1" do
    test "archives open incident and clears current_issue_id", %{
      user: user,
      account: account,
      project: project
    } do
      hb = heartbeat_fixture(account, user, project, %{paused: true, failure_threshold: 1})
      {:ok, hb} = Monitoring.update_heartbeat(hb, %{paused: false})

      {:ok, _} =
        Monitoring.update_heartbeat_runtime(hb, %{
          consecutive_failures: 1,
          status: :down
        })

      hb = Repo.get!(Heartbeat, hb.id)

      {:ok, issue} = HeartbeatIncidentLifecycle.create_or_reopen_incident(hb)
      hb = Repo.get!(Heartbeat, hb.id)

      assert :ok = HeartbeatIncidentLifecycle.handle_recovery(hb)

      updated = Repo.get!(Heartbeat, hb.id)
      assert updated.current_issue_id == nil
      assert updated.status == :up

      archived_issue = Repo.get!(Issue, issue.id)
      assert archived_issue.status == :archived
    end

    test "no-ops when current_issue_id is nil", %{
      user: user,
      account: account,
      project: project
    } do
      hb = heartbeat_fixture(account, user, project, %{paused: true})
      assert :ok = HeartbeatIncidentLifecycle.handle_recovery(hb)
    end

    test "clears stale current_issue_id when issue is already archived", %{
      user: user,
      account: account,
      project: project
    } do
      hb = heartbeat_fixture(account, user, project, %{paused: true, failure_threshold: 1})
      {:ok, hb} = Monitoring.update_heartbeat(hb, %{paused: false})

      {:ok, _} =
        Monitoring.update_heartbeat_runtime(hb, %{
          consecutive_failures: 1,
          status: :down
        })

      hb = Repo.get!(Heartbeat, hb.id)

      {:ok, issue} = HeartbeatIncidentLifecycle.create_or_reopen_incident(hb)

      # Manually archive the issue (simulating external archive)
      {:ok, _} = Tracking.update_issue(issue, %{status: :archived})

      hb = Repo.get!(Heartbeat, hb.id)
      assert :ok = HeartbeatIncidentLifecycle.handle_recovery(hb)

      updated = Repo.get!(Heartbeat, hb.id)
      assert updated.current_issue_id == nil
    end
  end
end
