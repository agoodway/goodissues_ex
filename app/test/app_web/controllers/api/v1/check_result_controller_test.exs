defmodule FFWeb.Api.V1.CheckResultControllerTest do
  use FFWeb.ConnCase

  import FF.AccountsFixtures
  import FF.MonitoringFixtures
  import FF.TrackingFixtures

  alias FF.Monitoring

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

  defp seed_results(check, count) do
    now = DateTime.utc_now(:second)

    for i <- 1..count do
      {:ok, _} =
        Monitoring.create_check_result(check, %{
          status: :up,
          status_code: 200,
          response_ms: i,
          checked_at: DateTime.add(now, -i, :second)
        })
    end
  end

  describe "index" do
    test "lists results in reverse chronological order", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)
      seed_results(check, 3)

      conn = get(conn, ~p"/api/v1/projects/#{project.id}/checks/#{check.id}/results")

      assert %{"data" => results, "meta" => meta} = json_response(conn, 200)
      assert length(results) == 3
      assert meta["total"] == 3

      [first, second, third] = results
      assert first["response_ms"] == 1
      assert second["response_ms"] == 2
      assert third["response_ms"] == 3
    end

    test "respects per_page", %{conn: conn, user: user, account: account, project: project} do
      check = check_fixture(account, user, project)
      seed_results(check, 5)

      conn =
        get(conn, ~p"/api/v1/projects/#{project.id}/checks/#{check.id}/results?per_page=2")

      assert %{"data" => results, "meta" => meta} = json_response(conn, 200)
      assert length(results) == 2
      assert meta["per_page"] == 2
      assert meta["total"] == 5
      assert meta["total_pages"] == 3
    end

    test "404 when check belongs to another project", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)
      other_project = project_fixture(account)

      conn =
        get(conn, ~p"/api/v1/projects/#{other_project.id}/checks/#{check.id}/results")

      assert json_response(conn, 404)
    end

    test "rejects invalid pagination", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)

      conn =
        get(conn, ~p"/api/v1/projects/#{project.id}/checks/#{check.id}/results?per_page=0")

      assert json_response(conn, 400)
    end
  end

  describe "auth" do
    test "401 without token", %{project: project, user: user, account: account} do
      check = check_fixture(account, user, project)

      conn =
        build_conn()
        |> put_req_header("accept", "application/json")

      conn = get(conn, ~p"/api/v1/projects/#{project.id}/checks/#{check.id}/results")
      assert json_response(conn, 401)
    end
  end
end
