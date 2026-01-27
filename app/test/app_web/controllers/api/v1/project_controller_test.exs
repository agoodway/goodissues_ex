defmodule FFWeb.Api.V1.ProjectControllerTest do
  use FFWeb.ConnCase

  import FF.AccountsFixtures
  import FF.TrackingFixtures

  setup %{conn: conn} do
    {user, account} = user_with_account_fixture()
    {token, _api_key} = api_key_fixture(user, account, :private)

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    {:ok, conn: conn, user: user, account: account}
  end

  describe "index" do
    test "lists all projects for account", %{conn: conn, account: account} do
      project = project_fixture(account)

      conn = get(conn, ~p"/api/v1/projects")
      assert %{"data" => [project_json]} = json_response(conn, 200)
      assert project_json["id"] == project.id
      assert project_json["name"] == project.name
    end

    test "returns empty list when no projects exist", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/projects")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "does not list projects from other accounts", %{conn: conn} do
      {_other_user, other_account} = user_with_account_fixture()
      _other_project = project_fixture(other_account)

      conn = get(conn, ~p"/api/v1/projects")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns 401 without authentication", %{conn: conn} do
      conn =
        conn
        |> delete_req_header("authorization")
        |> get(~p"/api/v1/projects")

      assert json_response(conn, 401)
    end
  end

  describe "show" do
    test "returns project by id", %{conn: conn, account: account} do
      project = project_fixture(account)

      conn = get(conn, ~p"/api/v1/projects/#{project.id}")
      assert %{"data" => json} = json_response(conn, 200)
      assert json["id"] == project.id
      assert json["name"] == project.name
      assert json["description"] == project.description
    end

    test "returns 404 for non-existent project", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/projects/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end

    test "returns 404 for project from different account", %{conn: conn} do
      {_other_user, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)

      conn = get(conn, ~p"/api/v1/projects/#{other_project.id}")
      assert json_response(conn, 404)
    end
  end

  describe "create" do
    test "creates project with valid params", %{conn: conn, account: account} do
      params = %{name: "New Project", description: "A new project"}

      conn = post(conn, ~p"/api/v1/projects", params)
      assert %{"data" => %{"id" => id}} = json_response(conn, 201)

      project = FF.Tracking.get_project(account, id)
      assert project.name == "New Project"
      assert project.description == "A new project"
    end

    test "returns error for invalid params", %{conn: conn} do
      params = %{description: "Missing name"}

      conn = post(conn, ~p"/api/v1/projects", params)
      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["name"] != nil
    end

    test "returns 403 with read-only API key", %{conn: conn, user: user, account: account} do
      {read_only_token, _api_key} = api_key_fixture(user, account, :public)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{read_only_token}")
        |> post(~p"/api/v1/projects", %{name: "Test"})

      assert json_response(conn, 403)
    end
  end

  describe "update" do
    test "updates project with valid params", %{conn: conn, account: account} do
      project = project_fixture(account)
      params = %{name: "Updated Name", description: "Updated description"}

      conn = patch(conn, ~p"/api/v1/projects/#{project.id}", params)
      assert %{"data" => json} = json_response(conn, 200)
      assert json["name"] == "Updated Name"
      assert json["description"] == "Updated description"
    end

    test "updates only description (partial update)", %{conn: conn, account: account} do
      project = project_fixture(account, %{name: "Original Name"})
      params = %{description: "New description"}

      conn = patch(conn, ~p"/api/v1/projects/#{project.id}", params)
      assert %{"data" => json} = json_response(conn, 200)
      assert json["name"] == "Original Name"
      assert json["description"] == "New description"
    end

    test "returns 403 with read-only API key", %{conn: conn, user: user, account: account} do
      project = project_fixture(account)
      {read_only_token, _api_key} = api_key_fixture(user, account, :public)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{read_only_token}")
        |> patch(~p"/api/v1/projects/#{project.id}", %{name: "Test"})

      assert json_response(conn, 403)
    end

    test "returns error for name too long", %{conn: conn, account: account} do
      project = project_fixture(account)
      params = %{name: String.duplicate("a", 256)}

      conn = patch(conn, ~p"/api/v1/projects/#{project.id}", params)
      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "returns 404 for non-existent project", %{conn: conn} do
      conn = patch(conn, ~p"/api/v1/projects/#{Ecto.UUID.generate()}", %{name: "Test"})
      assert json_response(conn, 404)
    end

    test "returns 404 for project from different account", %{conn: conn} do
      {_other_user, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)

      conn = patch(conn, ~p"/api/v1/projects/#{other_project.id}", %{name: "Test"})
      assert json_response(conn, 404)
    end
  end

  describe "delete" do
    test "deletes project", %{conn: conn, account: account} do
      project = project_fixture(account)

      conn = delete(conn, ~p"/api/v1/projects/#{project.id}")
      assert response(conn, 204)

      assert FF.Tracking.get_project(account, project.id) == nil
    end

    test "returns 404 for non-existent project", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/projects/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end

    test "returns 404 for project from different account", %{conn: conn} do
      {_other_user, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)

      conn = delete(conn, ~p"/api/v1/projects/#{other_project.id}")
      assert json_response(conn, 404)
    end

    test "returns 403 with read-only API key", %{conn: conn, user: user, account: account} do
      project = project_fixture(account)
      {read_only_token, _api_key} = api_key_fixture(user, account, :public)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{read_only_token}")
        |> delete(~p"/api/v1/projects/#{project.id}")

      assert json_response(conn, 403)
    end
  end
end
