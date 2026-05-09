defmodule FF.Monitoring.HeartbeatCrudTest do
  use FF.DataCase, async: false

  import FF.AccountsFixtures
  import FF.MonitoringFixtures
  import FF.TrackingFixtures

  alias FF.Monitoring
  alias FF.Monitoring.Heartbeat

  setup do
    {user, account} = user_with_account_fixture()
    project = project_fixture(account)
    {:ok, user: user, account: account, project: project}
  end

  describe "create_heartbeat/3" do
    test "creates with defaults and generates token", %{
      user: user,
      account: account,
      project: project
    } do
      attrs = %{name: "nightly-backup", project_id: project.id}

      assert {:ok, %Heartbeat{} = hb} = Monitoring.create_heartbeat(account, user, attrs)
      assert hb.name == "nightly-backup"
      assert hb.interval_seconds == 300
      assert hb.grace_seconds == 0
      assert hb.failure_threshold == 1
      assert hb.reopen_window_hours == 24
      assert hb.paused == false
      assert hb.status == :unknown
      assert hb.consecutive_failures == 0
      assert hb.alert_rules == []
      assert hb.created_by_id == user.id
      assert hb.project_id == project.id
      assert String.length(hb.ping_token) == 42
      assert hb.next_due_at != nil
    end

    test "creates paused heartbeat without next_due_at", %{
      user: user,
      account: account,
      project: project
    } do
      attrs = %{name: "paused-hb", project_id: project.id, paused: true}

      assert {:ok, %Heartbeat{} = hb} = Monitoring.create_heartbeat(account, user, attrs)
      assert hb.paused == true
      assert hb.next_due_at == nil
    end

    test "creates with custom interval and grace", %{
      user: user,
      account: account,
      project: project
    } do
      attrs = %{
        name: "custom",
        project_id: project.id,
        interval_seconds: 86_400,
        grace_seconds: 1800
      }

      assert {:ok, %Heartbeat{} = hb} = Monitoring.create_heartbeat(account, user, attrs)
      assert hb.interval_seconds == 86_400
      assert hb.grace_seconds == 1800
    end

    test "creates with alert rules", %{user: user, account: account, project: project} do
      rules = [%{"field" => "rows", "op" => "lt", "value" => 100}]
      attrs = %{name: "with-rules", project_id: project.id, alert_rules: rules}

      assert {:ok, %Heartbeat{} = hb} = Monitoring.create_heartbeat(account, user, attrs)
      assert length(hb.alert_rules) == 1
    end

    test "rejects invalid interval", %{user: user, account: account, project: project} do
      attrs = %{name: "bad", project_id: project.id, interval_seconds: 10}

      assert {:error, changeset} = Monitoring.create_heartbeat(account, user, attrs)
      assert errors_on(changeset).interval_seconds != nil
    end

    test "rejects invalid alert rule structure", %{user: user, account: account, project: project} do
      rules = [%{"field" => "x"}]
      attrs = %{name: "bad-rules", project_id: project.id, alert_rules: rules}

      assert {:error, changeset} = Monitoring.create_heartbeat(account, user, attrs)
      assert errors_on(changeset).alert_rules != nil
    end

    test "rejects invalid operator in alert rules", %{
      user: user,
      account: account,
      project: project
    } do
      rules = [%{"field" => "x", "op" => "contains", "value" => "y"}]
      attrs = %{name: "bad-op", project_id: project.id, alert_rules: rules}

      assert {:error, changeset} = Monitoring.create_heartbeat(account, user, attrs)
      assert errors_on(changeset).alert_rules != nil
    end

    test "rejects nested field paths", %{user: user, account: account, project: project} do
      rules = [%{"field" => "stats.rows", "op" => "gt", "value" => 0}]
      attrs = %{name: "nested", project_id: project.id, alert_rules: rules}

      assert {:error, changeset} = Monitoring.create_heartbeat(account, user, attrs)
      assert errors_on(changeset).alert_rules != nil
    end

    test "rejects project from another account", %{user: user} do
      {_other_user, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)
      {_, account} = user_with_account_fixture(%{user: %{}})

      attrs = %{name: "cross-account", project_id: other_project.id}

      assert {:error, changeset} = Monitoring.create_heartbeat(account, user, attrs)
      assert errors_on(changeset).project_id != nil
    end
  end

  describe "list_heartbeats/3" do
    test "returns paginated heartbeats", %{user: user, account: account, project: project} do
      heartbeat_fixture(account, user, project, %{name: "alpha", paused: true})
      heartbeat_fixture(account, user, project, %{name: "beta", paused: true})

      result = Monitoring.list_heartbeats(account, project.id)

      assert length(result.heartbeats) == 2
      assert result.total == 2
      assert result.page == 1
    end
  end

  describe "get_heartbeat/3" do
    test "returns heartbeat scoped to account", %{user: user, account: account, project: project} do
      hb = heartbeat_fixture(account, user, project, %{paused: true})

      assert %Heartbeat{} = Monitoring.get_heartbeat(account, project.id, hb.id)
    end

    test "returns nil for wrong project", %{user: user, account: account, project: project} do
      hb = heartbeat_fixture(account, user, project, %{paused: true})
      other_project = project_fixture(account, %{name: "other"})

      assert Monitoring.get_heartbeat(account, other_project.id, hb.id) == nil
    end
  end

  describe "get_heartbeat_by_token/2" do
    test "returns heartbeat by token and project", %{
      user: user,
      account: account,
      project: project
    } do
      hb = heartbeat_fixture(account, user, project, %{paused: true})

      assert %Heartbeat{id: id} = Monitoring.get_heartbeat_by_token(project.id, hb.ping_token)
      assert id == hb.id
    end

    test "returns nil for wrong project", %{user: user, account: account, project: project} do
      hb = heartbeat_fixture(account, user, project, %{paused: true})
      other_project = project_fixture(account, %{name: "other"})

      assert Monitoring.get_heartbeat_by_token(other_project.id, hb.ping_token) == nil
    end

    test "returns nil for invalid token", %{project: project} do
      assert Monitoring.get_heartbeat_by_token(project.id, "nonexistent") == nil
    end
  end

  describe "update_heartbeat/2" do
    test "updates name and interval", %{user: user, account: account, project: project} do
      hb = heartbeat_fixture(account, user, project, %{paused: true})

      assert {:ok, updated} =
               Monitoring.update_heartbeat(hb, %{name: "renamed", interval_seconds: 60})

      assert updated.name == "renamed"
      assert updated.interval_seconds == 60
    end

    test "updates alert rules (replaces entirely)", %{
      user: user,
      account: account,
      project: project
    } do
      rules = [%{"field" => "x", "op" => "eq", "value" => 1}]
      hb = heartbeat_fixture(account, user, project, %{paused: true, alert_rules: rules})

      new_rules = [%{"field" => "y", "op" => "gt", "value" => 5}]
      assert {:ok, updated} = Monitoring.update_heartbeat(hb, %{alert_rules: new_rules})
      assert length(updated.alert_rules) == 1
      assert hd(updated.alert_rules)["field"] == "y"
    end
  end

  describe "delete_heartbeat/1" do
    test "deletes heartbeat", %{user: user, account: account, project: project} do
      hb = heartbeat_fixture(account, user, project, %{paused: true})

      assert {:ok, %Heartbeat{}} = Monitoring.delete_heartbeat(hb)
      assert Monitoring.get_heartbeat(account, project.id, hb.id) == nil
    end
  end
end
