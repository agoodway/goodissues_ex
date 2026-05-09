defmodule GIWeb.Dashboard.CheckLiveTest do
  use GIWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import GI.AccountsFixtures
  import GI.MonitoringFixtures
  import GI.TrackingFixtures

  alias GI.Monitoring

  describe "Index" do
    setup :register_and_log_in_user_with_account

    setup %{account: account} do
      project = project_fixture(account, %{name: "Uptime Project", prefix: "UP"})
      %{project: project}
    end

    test "shows empty state when no checks", %{conn: conn, account: account, project: project} do
      {:ok, _live, html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}/checks")

      assert html =~ "Uptime Checks"
      assert html =~ "No uptime checks configured"
      assert html =~ "Create first check"
    end

    test "lists checks for a project", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{name: "API Health"})

      {:ok, _live, html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}/checks")

      assert html =~ "API Health"
      assert html =~ check.url
    end

    test "pause/resume toggle works", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{name: "Toggle Check"})

      {:ok, live, _html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}/checks")

      # Pause the check (target the desktop button which has opacity class)
      live
      |> element("button[phx-click='toggle_pause'][phx-value-id='#{check.id}'].opacity-0")
      |> render_click()

      # Verify it was paused
      updated = Monitoring.get_check(account, project.id, check.id)
      assert updated.paused == true
    end

    test "realtime updates via PubSub", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      {:ok, live, _html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}/checks")

      # Simulate a check being created
      check = check_fixture(account, user, project, %{name: "New Realtime Check"})

      # The PubSub message should update the view
      html = render(live)
      assert html =~ "New Realtime Check"
    end
  end

  describe "New" do
    setup :register_and_log_in_user_with_account

    setup %{account: account} do
      project = project_fixture(account, %{name: "Check Project", prefix: "CP"})
      %{project: project}
    end

    test "renders form", %{conn: conn, account: account, project: project} do
      {:ok, _live, html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}/checks/new")

      assert html =~ "New Check"
      assert html =~ "Name"
      assert html =~ "URL"
    end

    test "creates check with basic fields", %{conn: conn, account: account, project: project} do
      {:ok, live, _html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}/checks/new")

      live
      |> form("#check-form", check: %{name: "My Check", url: "https://example.com/health"})
      |> render_submit()

      assert_redirect(live, ~p"/dashboard/#{account.slug}/projects/#{project.id}/checks")
    end

    test "shows validation errors", %{conn: conn, account: account, project: project} do
      {:ok, live, _html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}/checks/new")

      html =
        live
        |> form("#check-form", check: %{name: "", url: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "Show" do
    setup :register_and_log_in_user_with_account

    setup %{user: user, account: account} do
      project = project_fixture(account, %{name: "Show Project", prefix: "SP"})
      check = check_fixture(account, user, project, %{name: "Show Check"})
      %{project: project, check: check}
    end

    test "shows check configuration", %{
      conn: conn,
      account: account,
      project: project,
      check: check
    } do
      {:ok, _live, html} =
        live(
          conn,
          ~p"/dashboard/#{account.slug}/projects/#{project.id}/checks/#{check.id}"
        )

      assert html =~ "Show Check"
      assert html =~ check.url
      assert html =~ "GET"
      assert html =~ "Configuration"
    end

    test "shows check results", %{
      conn: conn,
      account: account,
      project: project,
      check: check
    } do
      Monitoring.create_check_result(check, %{
        status: :up,
        status_code: 200,
        response_ms: 150,
        checked_at: DateTime.utc_now(:second)
      })

      {:ok, _live, html} =
        live(
          conn,
          ~p"/dashboard/#{account.slug}/projects/#{project.id}/checks/#{check.id}"
        )

      assert html =~ "200"
      assert html =~ "150ms"
    end

    test "filters results by status", %{
      conn: conn,
      account: account,
      project: project,
      check: check
    } do
      Monitoring.create_check_result(check, %{
        status: :up,
        status_code: 200,
        response_ms: 100,
        checked_at: DateTime.utc_now(:second)
      })

      Monitoring.create_check_result(check, %{
        status: :down,
        status_code: 500,
        response_ms: 200,
        error: "server error",
        checked_at: DateTime.utc_now(:second)
      })

      {:ok, live, _html} =
        live(
          conn,
          ~p"/dashboard/#{account.slug}/projects/#{project.id}/checks/#{check.id}"
        )

      # Filter to show only down results
      html = live |> element("form") |> render_change(%{status: "down"})
      assert html =~ "server error"
    end

    test "delete check redirects to index", %{
      conn: conn,
      account: account,
      project: project,
      check: check
    } do
      {:ok, live, _html} =
        live(
          conn,
          ~p"/dashboard/#{account.slug}/projects/#{project.id}/checks/#{check.id}"
        )

      live |> element("[phx-click='delete']") |> render_click()

      assert_redirect(live, ~p"/dashboard/#{account.slug}/projects/#{project.id}/checks")
    end

    test "edit modal shows and saves", %{
      conn: conn,
      account: account,
      project: project,
      check: check
    } do
      {:ok, live, _html} =
        live(
          conn,
          ~p"/dashboard/#{account.slug}/projects/#{project.id}/checks/#{check.id}/edit"
        )

      html = render(live)
      assert html =~ "Edit Check"
      assert html =~ check.name

      live
      |> form("#check-edit-form", check: %{name: "Renamed Check"})
      |> render_submit()

      assert_patch(
        live,
        ~p"/dashboard/#{account.slug}/projects/#{project.id}/checks/#{check.id}"
      )
    end
  end

  describe "Project show monitoring card" do
    setup :register_and_log_in_user_with_account

    setup %{user: user, account: account} do
      project = project_fixture(account, %{name: "Card Project", prefix: "CARD"})
      %{project: project, user: user}
    end

    test "shows monitoring card with zero checks", %{
      conn: conn,
      account: account,
      project: project
    } do
      {:ok, _live, html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}")

      assert html =~ "Monitoring"
      assert html =~ "View checks"
      assert html =~ "Create first check"
    end

    test "shows monitoring card with check counts", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{name: "Card Check"})
      Monitoring.update_runtime_fields(check, %{status: :up})

      {:ok, _live, html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}")

      assert html =~ "Monitoring"
      assert html =~ "All clear"
    end
  end
end
