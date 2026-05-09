defmodule GIWeb.Api.V1.CheckControllerTest do
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
    test "creates a check with valid params", %{conn: conn, project: project} do
      conn =
        post(conn, ~p"/api/v1/projects/#{project.id}/checks", %{
          "name" => "API",
          "url" => "https://api.example.com/health",
          "interval_seconds" => 60,
          "paused" => true
        })

      assert %{"data" => check} = json_response(conn, 201)
      assert check["name"] == "API"
      assert check["url"] == "https://api.example.com/health"
      assert check["interval_seconds"] == 60
      assert check["status"] == "unknown"
      assert check["project_id"] == project.id
    end

    test "returns 422 on invalid url", %{conn: conn, project: project} do
      conn =
        post(conn, ~p"/api/v1/projects/#{project.id}/checks", %{
          "name" => "X",
          "url" => "not-a-url"
        })

      assert json_response(conn, 422)
    end

    test "returns 404 when project belongs to another account", %{conn: conn} do
      {other_user, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)
      _ = other_user

      conn =
        post(conn, ~p"/api/v1/projects/#{other_project.id}/checks", %{
          "name" => "X",
          "url" => "https://example.com"
        })

      assert json_response(conn, 404)
    end
  end

  describe "index" do
    test "lists paginated checks with envelope", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      _c1 = check_fixture(account, user, project, %{name: "alpha"})
      _c2 = check_fixture(account, user, project, %{name: "beta"})

      conn = get(conn, ~p"/api/v1/projects/#{project.id}/checks")

      assert %{"data" => data, "meta" => meta} = json_response(conn, 200)
      assert length(data) == 2
      assert meta["page"] == 1
      assert meta["per_page"] == 20
      assert meta["total"] == 2
    end

    test "respects per_page parameter", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      for i <- 1..3, do: check_fixture(account, user, project, %{name: "c#{i}"})

      conn = get(conn, ~p"/api/v1/projects/#{project.id}/checks?per_page=1")

      assert %{"data" => [_], "meta" => meta} = json_response(conn, 200)
      assert meta["per_page"] == 1
      assert meta["total_pages"] == 3
    end

    test "rejects invalid pagination", %{conn: conn, project: project} do
      conn = get(conn, ~p"/api/v1/projects/#{project.id}/checks?page=abc")
      assert json_response(conn, 400)
    end

    test "404 when project not in account", %{conn: conn} do
      {_, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)
      conn = get(conn, ~p"/api/v1/projects/#{other_project.id}/checks")
      assert json_response(conn, 404)
    end
  end

  describe "show" do
    test "returns the check", %{conn: conn, user: user, account: account, project: project} do
      check = check_fixture(account, user, project, %{name: "Health"})

      conn = get(conn, ~p"/api/v1/projects/#{project.id}/checks/#{check.id}")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == check.id
      assert data["name"] == "Health"
    end

    test "404 when check belongs to a different project", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)
      other_project = project_fixture(account)

      conn = get(conn, ~p"/api/v1/projects/#{other_project.id}/checks/#{check.id}")
      assert json_response(conn, 404)
    end

    test "404 for unknown check id", %{conn: conn, project: project} do
      conn = get(conn, ~p"/api/v1/projects/#{project.id}/checks/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end
  end

  describe "update" do
    test "updates fields", %{conn: conn, user: user, account: account, project: project} do
      check = check_fixture(account, user, project)

      conn =
        patch(conn, ~p"/api/v1/projects/#{project.id}/checks/#{check.id}", %{
          "interval_seconds" => 120,
          "name" => "Renamed"
        })

      assert %{"data" => data} = json_response(conn, 200)
      assert data["interval_seconds"] == 120
      assert data["name"] == "Renamed"
    end

    test "404 across project boundary", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)
      other_project = project_fixture(account)

      conn =
        patch(conn, ~p"/api/v1/projects/#{other_project.id}/checks/#{check.id}", %{
          "name" => "x"
        })

      assert json_response(conn, 404)
    end

    test "422 on invalid update", %{conn: conn, user: user, account: account, project: project} do
      check = check_fixture(account, user, project)

      conn =
        patch(conn, ~p"/api/v1/projects/#{project.id}/checks/#{check.id}", %{
          "url" => "ftp://no"
        })

      assert json_response(conn, 422)
    end
  end

  describe "delete" do
    test "removes the check", %{conn: conn, user: user, account: account, project: project} do
      check = check_fixture(account, user, project)

      conn = delete(conn, ~p"/api/v1/projects/#{project.id}/checks/#{check.id}")
      assert response(conn, 204)
    end

    test "404 across project boundary", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)
      other_project = project_fixture(account)
      conn = delete(conn, ~p"/api/v1/projects/#{other_project.id}/checks/#{check.id}")
      assert json_response(conn, 404)
    end
  end

  describe "auth" do
    test "401 without bearer token", %{project: project} do
      conn = build_conn() |> put_req_header("accept", "application/json")
      conn = get(conn, ~p"/api/v1/projects/#{project.id}/checks")
      assert json_response(conn, 401)
    end

    test "403 when private key only has projects:read scope", %{
      conn: _conn,
      user: user,
      account: account,
      project: project
    } do
      account_user = GI.Accounts.get_account_user(user, account)

      {:ok, {_api_key, token}} =
        GI.Accounts.create_api_key(account_user, %{
          name: "scoped",
          type: :private,
          scopes: ["projects:read"]
        })

      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{token}")

      conn = get(conn, ~p"/api/v1/projects/#{project.id}/checks")
      assert json_response(conn, 403)
    end
  end
end
