defmodule GIWeb.Dashboard.HeartbeatLiveTest do
  use GIWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import GI.AccountsFixtures
  import GI.MonitoringFixtures
  import GI.TrackingFixtures

  alias GI.Monitoring

  describe "Index" do
    setup :register_and_log_in_user_with_account

    setup %{account: account} do
      project = project_fixture(account, %{name: "Heartbeat Project", prefix: "HB"})
      %{project: project}
    end

    test "shows empty state when no heartbeats", %{
      conn: conn,
      account: account,
      project: project
    } do
      {:ok, _live, html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats")

      assert html =~ "Heartbeats"
      assert html =~ "No heartbeat monitors configured"
      assert html =~ "Create first heartbeat"
    end

    test "lists heartbeats for a project", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      heartbeat_fixture(account, user, project, %{name: "Nightly Backup"})

      {:ok, _live, html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats")

      assert html =~ "Nightly Backup"
    end

    test "pause/resume toggle works", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      heartbeat = heartbeat_fixture(account, user, project, %{name: "Toggle HB"})

      {:ok, live, _html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats")

      live
      |> element("[data-testid='toggle-pause-#{heartbeat.id}']")
      |> render_click()

      updated = Monitoring.get_heartbeat(account, project.id, heartbeat.id)
      assert updated.paused == true
    end

    test "realtime updates via PubSub", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      {:ok, live, _html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats")

      # Create a heartbeat which broadcasts
      heartbeat_fixture(account, user, project, %{name: "Realtime HB"})

      html = render(live)
      assert html =~ "Realtime HB"
    end
  end

  describe "New" do
    setup :register_and_log_in_user_with_account

    setup %{account: account} do
      project = project_fixture(account, %{name: "HB Create Project", prefix: "HBC"})
      %{project: project}
    end

    test "renders form", %{conn: conn, account: account, project: project} do
      {:ok, _live, html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats/new")

      assert html =~ "New Heartbeat"
      assert html =~ "Name"
      assert html =~ "Interval"
    end

    test "creates heartbeat with basic fields", %{
      conn: conn,
      account: account,
      project: project
    } do
      {:ok, live, _html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats/new")

      live
      |> form("#heartbeat-form", heartbeat: %{name: "My HB", interval_seconds: 300})
      |> render_submit()

      # Should redirect to the heartbeat show page
      {path, _flash} = assert_redirect(live)
      assert path =~ "/heartbeats/"
    end

    test "shows validation errors", %{conn: conn, account: account, project: project} do
      {:ok, live, _html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats/new")

      html =
        live
        |> form("#heartbeat-form", heartbeat: %{name: "", interval_seconds: 10})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "Show" do
    setup :register_and_log_in_user_with_account

    setup %{user: user, account: account} do
      project = project_fixture(account, %{name: "Show HB Project", prefix: "SHB"})
      heartbeat = heartbeat_fixture(account, user, project, %{name: "Show Heartbeat"})
      %{project: project, heartbeat: heartbeat}
    end

    test "shows heartbeat configuration", %{
      conn: conn,
      account: account,
      project: project,
      heartbeat: heartbeat
    } do
      {:ok, _live, html} =
        live(
          conn,
          ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats/#{heartbeat.id}"
        )

      assert html =~ "Show Heartbeat"
      assert html =~ "Configuration"
      assert html =~ "Interval"
    end

    test "reveals ping URL for managers", %{
      conn: conn,
      account: account,
      project: project,
      heartbeat: heartbeat
    } do
      {:ok, live, html} =
        live(
          conn,
          ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats/#{heartbeat.id}"
        )

      assert html =~ "Reveal Ping URL"

      html = live |> element("[phx-click='reveal_ping_url']") |> render_click()

      assert html =~ "/api/v1/projects/#{project.id}/heartbeats/"
      assert html =~ "POST"
      assert html =~ "Copy"
    end

    test "delete heartbeat redirects to index", %{
      conn: conn,
      account: account,
      project: project,
      heartbeat: heartbeat
    } do
      {:ok, live, _html} =
        live(
          conn,
          ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats/#{heartbeat.id}"
        )

      live |> element("[phx-click='delete']") |> render_click()

      assert_redirect(live, ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats")
    end

    test "edit modal shows and saves", %{
      conn: conn,
      account: account,
      project: project,
      heartbeat: heartbeat
    } do
      {:ok, live, _html} =
        live(
          conn,
          ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats/#{heartbeat.id}/edit"
        )

      html = render(live)
      assert html =~ "Edit Heartbeat"
      assert html =~ heartbeat.name

      live
      |> form("#heartbeat-edit-form", heartbeat: %{name: "Renamed HB"})
      |> render_submit()

      assert_patch(
        live,
        ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats/#{heartbeat.id}"
      )
    end

    test "filters pings by kind", %{
      conn: conn,
      account: account,
      project: project,
      heartbeat: heartbeat
    } do
      # Create a ping
      Monitoring.receive_ping(heartbeat, :ping)

      {:ok, live, _html} =
        live(
          conn,
          ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats/#{heartbeat.id}"
        )

      # Filter to show only fail pings (should show empty)
      html = live |> element("form") |> render_change(%{kind: "fail"})
      assert html =~ "No pings yet"
    end
  end

  describe "context additions" do
    setup do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      {:ok, user: user, account: account, project: project}
    end

    test "change_heartbeat/2 returns changeset for new heartbeat" do
      changeset = Monitoring.change_heartbeat(%Monitoring.Heartbeat{})
      assert %Ecto.Changeset{} = changeset
    end

    test "change_heartbeat/2 returns update changeset for persisted heartbeat", %{
      user: user,
      account: account,
      project: project
    } do
      heartbeat = heartbeat_fixture(account, user, project)
      changeset = Monitoring.change_heartbeat(heartbeat, %{name: "Updated"})
      assert %Ecto.Changeset{} = changeset
      assert Ecto.Changeset.get_change(changeset, :name) == "Updated"
    end

    test "heartbeats_topic/1 returns topic string" do
      assert Monitoring.heartbeats_topic("some-id") == "heartbeats:project:some-id"
    end

    test "count_heartbeats_by_status/2 returns zeros when no heartbeats", %{
      account: account,
      project: project
    } do
      assert Monitoring.count_heartbeats_by_status(account, project.id) == %{
               up: 0,
               down: 0,
               unknown: 0,
               paused: 0
             }
    end

    test "count_heartbeats_by_status/2 counts by status", %{
      user: user,
      account: account,
      project: project
    } do
      hb1 = heartbeat_fixture(account, user, project, %{name: "HB1"})
      _hb2 = heartbeat_fixture(account, user, project, %{name: "HB2", paused: true})

      Monitoring.update_heartbeat_runtime(hb1, %{status: :up})

      result = Monitoring.count_heartbeats_by_status(account, project.id)
      assert result.up == 1
      assert result.paused == 1
    end

    test "reveal_ping_url/1 returns URL with token", %{
      user: user,
      account: account,
      project: project
    } do
      heartbeat = heartbeat_fixture(account, user, project)
      url = Monitoring.reveal_ping_url(heartbeat)
      assert url =~ "/api/v1/projects/#{project.id}/heartbeats/"
      assert url =~ "/ping"
    end

    test "list_heartbeat_pings filters by kind", %{
      user: user,
      account: account,
      project: project
    } do
      heartbeat = heartbeat_fixture(account, user, project)
      Monitoring.receive_ping(heartbeat, :ping)
      Monitoring.receive_ping(heartbeat, :start)

      # All
      result = Monitoring.list_heartbeat_pings(heartbeat, %{})
      assert result.total == 2

      # Filter by kind
      result = Monitoring.list_heartbeat_pings(heartbeat, %{kind: "start"})
      assert result.total == 1
      assert hd(result.pings).kind == :start
    end
  end

  describe "project show monitoring card with heartbeats" do
    setup :register_and_log_in_user_with_account

    setup %{user: user, account: account} do
      project = project_fixture(account, %{name: "Mon Card Project", prefix: "MCP"})
      %{project: project, user: user}
    end

    test "shows heartbeat counts in monitoring card", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      heartbeat_fixture(account, user, project, %{name: "Card HB"})

      {:ok, _live, html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}")

      assert html =~ "Heartbeats"
      assert html =~ "View heartbeats"
    end

    test "shows create first heartbeat link when none exist", %{
      conn: conn,
      account: account,
      project: project
    } do
      {:ok, _live, html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}")

      assert html =~ "Create first heartbeat"
    end
  end

  describe "breadcrumbs" do
    setup :register_and_log_in_user_with_account

    setup %{user: user, account: account} do
      project = project_fixture(account, %{name: "Breadcrumb Project", prefix: "BC"})
      heartbeat = heartbeat_fixture(account, user, project, %{name: "BC Heartbeat"})
      %{project: project, heartbeat: heartbeat}
    end

    test "index page shows breadcrumb", %{conn: conn, account: account, project: project} do
      {:ok, _live, html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats")

      assert html =~ "BC"
      assert html =~ "Heartbeats"
    end

    test "show page shows breadcrumb with heartbeat name", %{
      conn: conn,
      account: account,
      project: project,
      heartbeat: heartbeat
    } do
      {:ok, _live, html} =
        live(
          conn,
          ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats/#{heartbeat.id}"
        )

      assert html =~ "BC"
      assert html =~ "Heartbeats"
      assert html =~ "BC Heartbeat"
    end
  end

  describe "non-manager access" do
    setup do
      # Create an account with a manager and a member
      {manager, account} = user_with_account_fixture()
      project = project_fixture(account, %{name: "Auth Project", prefix: "AUTH"})
      heartbeat = heartbeat_fixture(account, manager, project, %{name: "Auth HB"})

      # Create a member user (non-manager)
      member = user_fixture(%{email: "member#{System.unique_integer()}@example.com"})
      GI.Accounts.add_user_to_account(account, member, :member)

      %{account: account, project: project, heartbeat: heartbeat, viewer: member}
    end

    test "viewer cannot see ping URL reveal", %{
      conn: conn,
      account: account,
      project: project,
      heartbeat: heartbeat,
      viewer: viewer
    } do
      conn = log_in_user(conn, viewer)

      {:ok, _live, html} =
        live(
          conn,
          ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats/#{heartbeat.id}"
        )

      refute html =~ "Reveal Ping URL"
      assert html =~ "Read-only access"
    end

    test "viewer cannot see create button on index", %{
      conn: conn,
      account: account,
      project: project,
      viewer: viewer
    } do
      conn = log_in_user(conn, viewer)

      {:ok, _live, html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats")

      refute html =~ "New Heartbeat"
    end

    test "non-manager toggle_pause event returns error", %{
      conn: conn,
      account: account,
      project: project,
      heartbeat: heartbeat,
      viewer: viewer
    } do
      conn = log_in_user(conn, viewer)

      {:ok, live, _html} =
        live(
          conn,
          ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats/#{heartbeat.id}"
        )

      html = render_click(live, "toggle_pause")
      assert html =~ "You don&#39;t have permission"
    end

    test "non-manager delete event returns error", %{
      conn: conn,
      account: account,
      project: project,
      heartbeat: heartbeat,
      viewer: viewer
    } do
      conn = log_in_user(conn, viewer)

      {:ok, live, _html} =
        live(
          conn,
          ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats/#{heartbeat.id}"
        )

      html = render_click(live, "delete")
      assert html =~ "You don&#39;t have permission"
    end

    test "non-manager reveal_ping_url event returns error", %{
      conn: conn,
      account: account,
      project: project,
      heartbeat: heartbeat,
      viewer: viewer
    } do
      conn = log_in_user(conn, viewer)

      {:ok, live, _html} =
        live(
          conn,
          ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats/#{heartbeat.id}"
        )

      html = render_click(live, "reveal_ping_url")
      assert html =~ "You don&#39;t have permission"
    end

    test "non-manager save event returns error", %{
      conn: conn,
      account: account,
      project: project,
      heartbeat: heartbeat,
      viewer: viewer
    } do
      conn = log_in_user(conn, viewer)

      {:ok, live, _html} =
        live(
          conn,
          ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats/#{heartbeat.id}"
        )

      html = render_click(live, "save", %{"heartbeat" => %{"name" => "Hacked"}})
      assert html =~ "You don&#39;t have permission"
    end

    test "non-manager redirected from /new", %{
      conn: conn,
      account: account,
      project: project,
      viewer: viewer
    } do
      conn = log_in_user(conn, viewer)

      {:ok, _live, html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats/new")
        |> follow_redirect(conn)

      assert html =~ "You don&#39;t have permission to create heartbeats"
    end

    test "non-manager redirected from /edit", %{
      conn: conn,
      account: account,
      project: project,
      heartbeat: heartbeat,
      viewer: viewer
    } do
      conn = log_in_user(conn, viewer)

      {:error, {:live_redirect, %{to: to, flash: flash}}} =
        live(
          conn,
          ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats/#{heartbeat.id}/edit"
        )

      assert to =~ "/heartbeats/#{heartbeat.id}"
      assert flash["error"] =~ "permission to edit"
    end
  end

  describe "PubSub handlers" do
    setup :register_and_log_in_user_with_account

    setup %{user: user, account: account} do
      project = project_fixture(account, %{name: "PubSub Project", prefix: "PS"})
      heartbeat = heartbeat_fixture(account, user, project, %{name: "PubSub HB"})
      %{project: project, heartbeat: heartbeat}
    end

    test "index: heartbeat_updated refreshes heartbeat in list", %{
      conn: conn,
      account: account,
      project: project,
      heartbeat: heartbeat
    } do
      {:ok, live, _html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats")

      Phoenix.PubSub.broadcast(
        GI.PubSub,
        Monitoring.heartbeats_topic(project.id),
        {:heartbeat_updated, %{id: heartbeat.id, name: "Updated Name"}}
      )

      html = render(live)
      assert html =~ "Updated Name"
    end

    test "index: heartbeat_deleted removes heartbeat from list", %{
      conn: conn,
      account: account,
      project: project,
      heartbeat: heartbeat
    } do
      {:ok, live, _html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats")

      Phoenix.PubSub.broadcast(
        GI.PubSub,
        Monitoring.heartbeats_topic(project.id),
        {:heartbeat_deleted, %{id: heartbeat.id}}
      )

      html = render(live)
      refute html =~ "PubSub HB"
    end

    test "index: heartbeat_status_changed updates status", %{
      conn: conn,
      account: account,
      project: project,
      heartbeat: heartbeat
    } do
      {:ok, live, _html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats")

      Phoenix.PubSub.broadcast(
        GI.PubSub,
        Monitoring.heartbeats_topic(project.id),
        {:heartbeat_status_changed, %{id: heartbeat.id, status: :down, paused: false}}
      )

      html = render(live)
      assert html =~ "DOWN"
    end

    test "show: heartbeat_updated refreshes heartbeat data", %{
      conn: conn,
      account: account,
      project: project,
      heartbeat: heartbeat
    } do
      {:ok, live, _html} =
        live(
          conn,
          ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats/#{heartbeat.id}"
        )

      Phoenix.PubSub.broadcast(
        GI.PubSub,
        Monitoring.heartbeats_topic(project.id),
        {:heartbeat_updated, %{id: heartbeat.id, name: "Show Updated"}}
      )

      html = render(live)
      assert html =~ "Show Updated"
    end

    test "show: heartbeat_deleted redirects to index", %{
      conn: conn,
      account: account,
      project: project,
      heartbeat: heartbeat
    } do
      {:ok, live, _html} =
        live(
          conn,
          ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats/#{heartbeat.id}"
        )

      Phoenix.PubSub.broadcast(
        GI.PubSub,
        Monitoring.heartbeats_topic(project.id),
        {:heartbeat_deleted, %{id: heartbeat.id}}
      )

      assert_redirect(live, ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats")
    end

    test "show: heartbeat_ping_received updates heartbeat and prepends ping on page 1", %{
      conn: conn,
      account: account,
      project: project,
      heartbeat: heartbeat
    } do
      {:ok, live, _html} =
        live(
          conn,
          ~p"/dashboard/#{account.slug}/projects/#{project.id}/heartbeats/#{heartbeat.id}"
        )

      now = DateTime.utc_now()

      Phoenix.PubSub.broadcast(
        GI.PubSub,
        Monitoring.heartbeats_topic(project.id),
        {:heartbeat_ping_received,
         %{
           heartbeat_id: heartbeat.id,
           status: :up,
           last_ping_at: now,
           next_due_at: DateTime.add(now, 300, :second),
           paused: false,
           ping: %{
             id: Ecto.UUID.generate(),
             kind: :ping,
             duration_ms: nil,
             exit_code: nil,
             pinged_at: now,
             heartbeat_id: heartbeat.id
           }
         }}
      )

      html = render(live)
      assert html =~ "PING"
    end
  end
end
