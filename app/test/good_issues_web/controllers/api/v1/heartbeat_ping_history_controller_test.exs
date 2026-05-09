defmodule GIWeb.Api.V1.HeartbeatPingHistoryControllerTest do
  use GIWeb.ConnCase

  import GI.AccountsFixtures
  import GI.MonitoringFixtures
  import GI.TrackingFixtures

  alias GI.Monitoring

  setup %{conn: conn} do
    {user, account} = user_with_account_fixture()
    {token, _key} = api_key_fixture(user, account, :private)
    project = project_fixture(account)
    heartbeat = heartbeat_fixture(account, user, project, %{paused: true})

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    {:ok, conn: conn, user: user, account: account, project: project, heartbeat: heartbeat}
  end

  describe "index" do
    test "returns paginated pings", %{
      conn: conn,
      project: project,
      heartbeat: heartbeat
    } do
      # Create some pings
      {:ok, _} = Monitoring.receive_ping(heartbeat, :start)
      heartbeat = GI.Repo.get!(GI.Monitoring.Heartbeat, heartbeat.id)
      {:ok, _} = Monitoring.receive_ping(heartbeat, :ping)

      conn =
        get(conn, ~p"/api/v1/projects/#{project.id}/heartbeats/#{heartbeat.id}/pings")

      assert %{"data" => pings, "meta" => meta} = json_response(conn, 200)
      assert length(pings) == 2
      assert meta["total"] == 2
      assert meta["page"] == 1
    end

    test "returns 404 for heartbeat in different project", %{
      conn: conn,
      account: account,
      heartbeat: heartbeat
    } do
      other_project = project_fixture(account, %{name: "other"})

      conn =
        get(conn, ~p"/api/v1/projects/#{other_project.id}/heartbeats/#{heartbeat.id}/pings")

      assert json_response(conn, 404)
    end

    test "returns 404 for heartbeat in different account", %{conn: conn, heartbeat: heartbeat} do
      {_other_user, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)

      conn =
        get(conn, ~p"/api/v1/projects/#{other_project.id}/heartbeats/#{heartbeat.id}/pings")

      assert json_response(conn, 404)
    end

    test "requires authentication", %{project: project, heartbeat: heartbeat} do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> get(~p"/api/v1/projects/#{project.id}/heartbeats/#{heartbeat.id}/pings")

      assert json_response(conn, 401)
    end

    test "supports pagination params", %{
      conn: conn,
      project: project,
      heartbeat: heartbeat
    } do
      # Create 3 pings
      {:ok, _} = Monitoring.receive_ping(heartbeat, :start)
      heartbeat = GI.Repo.get!(GI.Monitoring.Heartbeat, heartbeat.id)
      {:ok, _} = Monitoring.receive_ping(heartbeat, :ping)
      heartbeat = GI.Repo.get!(GI.Monitoring.Heartbeat, heartbeat.id)
      {:ok, _} = Monitoring.receive_ping(heartbeat, :fail)

      conn =
        get(
          conn,
          ~p"/api/v1/projects/#{project.id}/heartbeats/#{heartbeat.id}/pings?page=1&per_page=2"
        )

      assert %{"data" => pings, "meta" => meta} = json_response(conn, 200)
      assert length(pings) == 2
      assert meta["total"] == 3
      assert meta["total_pages"] == 2
    end

    test "response includes expected fields", %{
      conn: conn,
      project: project,
      heartbeat: heartbeat
    } do
      {:ok, _} = Monitoring.receive_ping(heartbeat, :ping)

      conn =
        get(conn, ~p"/api/v1/projects/#{project.id}/heartbeats/#{heartbeat.id}/pings")

      assert %{"data" => [ping]} = json_response(conn, 200)
      assert Map.has_key?(ping, "id")
      assert Map.has_key?(ping, "kind")
      assert Map.has_key?(ping, "pinged_at")
    end
  end
end
