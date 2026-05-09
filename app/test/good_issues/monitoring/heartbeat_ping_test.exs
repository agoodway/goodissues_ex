defmodule GI.Monitoring.HeartbeatPingTest do
  use GI.DataCase, async: false

  import GI.AccountsFixtures
  import GI.MonitoringFixtures
  import GI.TrackingFixtures

  alias GI.Monitoring
  alias GI.Monitoring.{Heartbeat, HeartbeatPing}
  alias GI.Repo

  setup do
    {user, account} = user_with_account_fixture()
    project = project_fixture(account)
    {:ok, user: user, account: account, project: project}
  end

  describe "receive_ping/3 - success ping" do
    test "records ping and resets state", %{user: user, account: account, project: project} do
      hb = heartbeat_fixture(account, user, project, %{paused: true})
      # Unpause to set next_due_at
      {:ok, hb} = Monitoring.update_heartbeat(hb, %{paused: false})

      assert {:ok, %HeartbeatPing{kind: :ping}} = Monitoring.receive_ping(hb, :ping)

      updated = Repo.get!(Heartbeat, hb.id)
      assert updated.status == :up
      assert updated.consecutive_failures == 0
      assert updated.last_ping_at != nil
      assert updated.started_at == nil
    end

    test "computes duration from start ping", %{user: user, account: account, project: project} do
      hb = heartbeat_fixture(account, user, project, %{paused: true})
      {:ok, hb} = Monitoring.update_heartbeat(hb, %{paused: false})

      # Send start ping
      {:ok, _} = Monitoring.receive_ping(hb, :start)

      # Small delay to get measurable duration
      hb = Repo.get!(Heartbeat, hb.id)
      {:ok, %HeartbeatPing{} = ping} = Monitoring.receive_ping(hb, :ping)

      assert ping.duration_ms != nil
      assert ping.duration_ms >= 0
    end

    test "alert rule failure on success ping increments failures", %{
      user: user,
      account: account,
      project: project
    } do
      rules = [%{"field" => "rows", "op" => "lt", "value" => 100}]
      hb = heartbeat_fixture(account, user, project, %{paused: true, alert_rules: rules})
      {:ok, hb} = Monitoring.update_heartbeat(hb, %{paused: false})

      {:ok, _} = Monitoring.receive_ping(hb, :ping, %{payload: %{"rows" => 50}})

      updated = Repo.get!(Heartbeat, hb.id)
      assert updated.consecutive_failures == 1
      assert updated.status == :down
    end

    test "alert rules pass — ping is success", %{user: user, account: account, project: project} do
      rules = [%{"field" => "rows", "op" => "lt", "value" => 100}]
      hb = heartbeat_fixture(account, user, project, %{paused: true, alert_rules: rules})
      {:ok, hb} = Monitoring.update_heartbeat(hb, %{paused: false})

      {:ok, _} = Monitoring.receive_ping(hb, :ping, %{payload: %{"rows" => 500}})

      updated = Repo.get!(Heartbeat, hb.id)
      assert updated.consecutive_failures == 0
      assert updated.status == :up
    end

    test "success ping with no payload and rules configured skips evaluation", %{
      user: user,
      account: account,
      project: project
    } do
      rules = [%{"field" => "rows", "op" => "lt", "value" => 100}]
      hb = heartbeat_fixture(account, user, project, %{paused: true, alert_rules: rules})
      {:ok, hb} = Monitoring.update_heartbeat(hb, %{paused: false})

      {:ok, _} = Monitoring.receive_ping(hb, :ping)

      updated = Repo.get!(Heartbeat, hb.id)
      assert updated.consecutive_failures == 0
      assert updated.status == :up
    end
  end

  describe "receive_ping/3 - start ping" do
    test "records start and sets started_at", %{user: user, account: account, project: project} do
      hb = heartbeat_fixture(account, user, project, %{paused: true})

      {:ok, %HeartbeatPing{kind: :start}} = Monitoring.receive_ping(hb, :start)

      updated = Repo.get!(Heartbeat, hb.id)
      assert updated.started_at != nil
    end

    test "stores payload on start ping", %{user: user, account: account, project: project} do
      hb = heartbeat_fixture(account, user, project, %{paused: true})

      {:ok, %HeartbeatPing{} = ping} =
        Monitoring.receive_ping(hb, :start, %{payload: %{"job" => "backup"}})

      assert ping.payload == %{"job" => "backup"}
    end
  end

  describe "receive_ping/3 - fail ping" do
    test "increments failures and clears started_at", %{
      user: user,
      account: account,
      project: project
    } do
      hb = heartbeat_fixture(account, user, project, %{paused: true})
      {:ok, hb} = Monitoring.update_heartbeat(hb, %{paused: false})

      # Send start first
      {:ok, _} = Monitoring.receive_ping(hb, :start)
      hb = Repo.get!(Heartbeat, hb.id)

      {:ok, %HeartbeatPing{kind: :fail}} = Monitoring.receive_ping(hb, :fail)

      updated = Repo.get!(Heartbeat, hb.id)
      assert updated.consecutive_failures == 1
      assert updated.started_at == nil
      assert updated.status == :down
    end

    test "stores exit_code and payload", %{user: user, account: account, project: project} do
      hb = heartbeat_fixture(account, user, project, %{paused: true})

      {:ok, %HeartbeatPing{} = ping} =
        Monitoring.receive_ping(hb, :fail, %{
          exit_code: 1,
          payload: %{"reason" => "disk full"}
        })

      assert ping.exit_code == 1
      assert ping.payload == %{"reason" => "disk full"}
    end
  end

  describe "receive_ping/3 - recovery" do
    test "recovers from down state on success ping", %{
      user: user,
      account: account,
      project: project
    } do
      hb = heartbeat_fixture(account, user, project, %{paused: true})
      {:ok, hb} = Monitoring.update_heartbeat(hb, %{paused: false})

      # Force down state with a fail ping
      {:ok, _} = Monitoring.receive_ping(hb, :fail)
      hb = Repo.get!(Heartbeat, hb.id)
      assert hb.status == :down

      # Success ping should recover
      {:ok, _} = Monitoring.receive_ping(hb, :ping)
      updated = Repo.get!(Heartbeat, hb.id)
      assert updated.status == :up
      assert updated.consecutive_failures == 0
    end
  end

  describe "list_heartbeat_pings/2" do
    test "returns paginated pings in reverse chronological order", %{
      user: user,
      account: account,
      project: project
    } do
      hb = heartbeat_fixture(account, user, project, %{paused: true})

      {:ok, _} = Monitoring.receive_ping(hb, :start)
      hb = Repo.get!(Heartbeat, hb.id)
      {:ok, _} = Monitoring.receive_ping(hb, :ping)

      result = Monitoring.list_heartbeat_pings(hb)
      assert length(result.pings) == 2
      assert result.total == 2
      # First ping should be most recent (success, not start)
      assert hd(result.pings).kind == :ping
    end
  end
end
