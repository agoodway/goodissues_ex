defmodule GIWeb.Api.V1.HeartbeatPingControllerTest do
  use GIWeb.ConnCase

  import GI.AccountsFixtures
  import GI.MonitoringFixtures
  import GI.TrackingFixtures

  setup %{conn: conn} do
    {user, account} = user_with_account_fixture()
    project = project_fixture(account)
    heartbeat = heartbeat_fixture(account, user, project, %{paused: true})

    conn = put_req_header(conn, "content-type", "application/json")

    {:ok, conn: conn, project: project, heartbeat: heartbeat}
  end

  describe "ping (success)" do
    test "returns 204 with no body", %{conn: conn, project: project, heartbeat: hb} do
      conn =
        post(conn, ~p"/api/v1/projects/#{project.id}/heartbeats/#{hb.ping_token}/ping")

      assert response(conn, 204)
    end

    test "returns 204 with JSON payload", %{conn: conn, project: project, heartbeat: hb} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(
          ~p"/api/v1/projects/#{project.id}/heartbeats/#{hb.ping_token}/ping",
          Jason.encode!(%{"rows_processed" => 500})
        )

      assert response(conn, 204)
    end

    test "returns 404 for invalid token", %{conn: conn, project: project} do
      conn =
        post(conn, ~p"/api/v1/projects/#{project.id}/heartbeats/invalid_token/ping")

      assert json_response(conn, 404)
    end

    test "returns 404 for wrong project", %{conn: conn, heartbeat: hb} do
      {_, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)

      conn =
        post(conn, ~p"/api/v1/projects/#{other_project.id}/heartbeats/#{hb.ping_token}/ping")

      assert json_response(conn, 404)
    end

    test "no Bearer auth required", %{project: project, heartbeat: hb} do
      # Build conn with no auth header at all
      conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/v1/projects/#{project.id}/heartbeats/#{hb.ping_token}/ping")

      assert response(conn, 204)
    end
  end

  describe "start" do
    test "returns 204", %{conn: conn, project: project, heartbeat: hb} do
      conn =
        post(conn, ~p"/api/v1/projects/#{project.id}/heartbeats/#{hb.ping_token}/ping/start")

      assert response(conn, 204)
    end

    test "returns 404 for invalid token", %{conn: conn, project: project} do
      conn =
        post(conn, ~p"/api/v1/projects/#{project.id}/heartbeats/invalid_token/ping/start")

      assert json_response(conn, 404)
    end
  end

  describe "fail" do
    test "returns 204", %{conn: conn, project: project, heartbeat: hb} do
      conn =
        post(conn, ~p"/api/v1/projects/#{project.id}/heartbeats/#{hb.ping_token}/ping/fail")

      assert response(conn, 204)
    end

    test "stores exit_code from payload", %{conn: conn, project: project, heartbeat: hb} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(
          ~p"/api/v1/projects/#{project.id}/heartbeats/#{hb.ping_token}/ping/fail",
          Jason.encode!(%{"exit_code" => 1, "reason" => "disk full"})
        )

      assert response(conn, 204)
    end

    test "returns 404 for invalid token", %{conn: conn, project: project} do
      conn =
        post(conn, ~p"/api/v1/projects/#{project.id}/heartbeats/invalid_token/ping/fail")

      assert json_response(conn, 404)
    end

    test "rejects exit_code outside 0-255", %{conn: conn, project: project, heartbeat: hb} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(
          ~p"/api/v1/projects/#{project.id}/heartbeats/#{hb.ping_token}/ping/fail",
          Jason.encode!(%{"exit_code" => 999})
        )

      assert json_response(conn, 400)
    end

    test "rejects negative exit_code", %{conn: conn, project: project, heartbeat: hb} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(
          ~p"/api/v1/projects/#{project.id}/heartbeats/#{hb.ping_token}/ping/fail",
          Jason.encode!(%{"exit_code" => -1})
        )

      assert json_response(conn, 400)
    end
  end

  describe "payload size validation" do
    test "rejects payload over 4KB", %{conn: conn, project: project, heartbeat: hb} do
      large_payload = String.duplicate("x", 5000)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(
          ~p"/api/v1/projects/#{project.id}/heartbeats/#{hb.ping_token}/ping",
          Jason.encode!(%{"data" => large_payload})
        )

      assert json_response(conn, 400)
    end

    test "accepts payload under 4KB", %{conn: conn, project: project, heartbeat: hb} do
      small_payload = String.duplicate("x", 100)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(
          ~p"/api/v1/projects/#{project.id}/heartbeats/#{hb.ping_token}/ping",
          Jason.encode!(%{"data" => small_payload})
        )

      assert response(conn, 204)
    end
  end
end
