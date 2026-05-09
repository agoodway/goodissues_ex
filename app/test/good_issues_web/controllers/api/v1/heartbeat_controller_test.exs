defmodule GIWeb.Api.V1.HeartbeatControllerTest do
  use GIWeb.ConnCase

  import GI.AccountsFixtures
  import GI.MonitoringFixtures
  import GI.TrackingFixtures

  setup %{conn: conn} do
    {user, account} = user_with_account_fixture()
    {token, _key} = api_key_fixture(user, account, :private)
    project = project_fixture(account)

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    {:ok, conn: conn, user: user, account: account, project: project}
  end

  describe "create" do
    test "creates heartbeat and returns ping URL", %{conn: conn, project: project} do
      conn =
        post(conn, ~p"/api/v1/projects/#{project.id}/heartbeats", %{
          "name" => "nightly-backup",
          "interval_seconds" => 86_400,
          "grace_seconds" => 1800,
          "paused" => true
        })

      assert %{"data" => hb} = json_response(conn, 201)
      assert hb["name"] == "nightly-backup"
      assert hb["interval_seconds"] == 86_400
      assert hb["grace_seconds"] == 1800
      assert hb["status"] == "unknown"
      assert hb["project_id"] == project.id
      assert String.length(hb["ping_token"]) == 42
      assert hb["ping_url"] =~ "/ping"
    end

    test "returns 422 on invalid interval", %{conn: conn, project: project} do
      conn =
        post(conn, ~p"/api/v1/projects/#{project.id}/heartbeats", %{
          "name" => "bad",
          "interval_seconds" => 10
        })

      assert json_response(conn, 422)
    end

    test "returns 404 for project in another account", %{conn: conn} do
      {_other_user, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)

      conn =
        post(conn, ~p"/api/v1/projects/#{other_project.id}/heartbeats", %{
          "name" => "cross-account"
        })

      assert json_response(conn, 404)
    end
  end

  describe "index" do
    test "lists heartbeats with pagination", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      heartbeat_fixture(account, user, project, %{name: "alpha", paused: true})
      heartbeat_fixture(account, user, project, %{name: "beta", paused: true})

      conn = get(conn, ~p"/api/v1/projects/#{project.id}/heartbeats")

      assert %{"data" => data, "meta" => meta} = json_response(conn, 200)
      assert length(data) == 2
      assert meta["total"] == 2
    end

    test "read responses redact token", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      heartbeat_fixture(account, user, project, %{paused: true})

      conn = get(conn, ~p"/api/v1/projects/#{project.id}/heartbeats")

      assert %{"data" => [hb]} = json_response(conn, 200)
      refute Map.has_key?(hb, "ping_token")
      refute Map.has_key?(hb, "ping_url")
    end
  end

  describe "show" do
    test "returns heartbeat without token", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      hb = heartbeat_fixture(account, user, project, %{paused: true})

      conn = get(conn, ~p"/api/v1/projects/#{project.id}/heartbeats/#{hb.id}")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == hb.id
      assert data["name"] == hb.name
      refute Map.has_key?(data, "ping_token")
    end

    test "returns 404 for wrong project", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      hb = heartbeat_fixture(account, user, project, %{paused: true})
      other_project = project_fixture(account, %{name: "other"})

      conn = get(conn, ~p"/api/v1/projects/#{other_project.id}/heartbeats/#{hb.id}")

      assert json_response(conn, 404)
    end
  end

  describe "update" do
    test "updates heartbeat", %{conn: conn, user: user, account: account, project: project} do
      hb = heartbeat_fixture(account, user, project, %{paused: true})

      conn =
        patch(conn, ~p"/api/v1/projects/#{project.id}/heartbeats/#{hb.id}", %{
          "name" => "renamed"
        })

      assert %{"data" => data} = json_response(conn, 200)
      assert data["name"] == "renamed"
    end

    test "returns 422 on invalid interval", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      hb = heartbeat_fixture(account, user, project, %{paused: true})

      conn =
        patch(conn, ~p"/api/v1/projects/#{project.id}/heartbeats/#{hb.id}", %{
          "interval_seconds" => 5
        })

      assert json_response(conn, 422)
    end
  end

  describe "delete" do
    test "deletes heartbeat", %{conn: conn, user: user, account: account, project: project} do
      hb = heartbeat_fixture(account, user, project, %{paused: true})

      conn = delete(conn, ~p"/api/v1/projects/#{project.id}/heartbeats/#{hb.id}")

      assert response(conn, 204)
    end
  end

  describe "auth" do
    test "read-only key can list but not create", %{
      user: user,
      account: account,
      project: project
    } do
      {read_token, _key} = api_key_fixture(user, account, :public)

      read_conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{read_token}")

      # Read should work
      conn = get(read_conn, ~p"/api/v1/projects/#{project.id}/heartbeats")
      assert json_response(conn, 200)

      # Write should be forbidden
      conn =
        post(read_conn, ~p"/api/v1/projects/#{project.id}/heartbeats", %{
          "name" => "nope"
        })

      assert json_response(conn, 403)
    end
  end
end
