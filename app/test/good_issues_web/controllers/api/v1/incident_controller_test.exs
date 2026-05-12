defmodule GIWeb.Api.V1.IncidentControllerTest do
  use GIWeb.ConnCase

  import GI.AccountsFixtures
  import GI.TrackingFixtures

  alias GI.Tracking

  setup %{conn: conn} do
    {user, account} = user_with_account_fixture()
    {token, _api_key} = api_key_fixture(user, account, :private)
    project = project_fixture(account)

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    {:ok, conn: conn, user: user, account: account, project: project}
  end

  describe "index" do
    test "lists all incidents for account", %{
      conn: conn,
      account: account,
      user: user,
      project: project
    } do
      _incident = incident_fixture(account, user, project)

      conn = get(conn, ~p"/api/v1/incidents")

      assert %{"data" => [incident_json], "meta" => meta} = json_response(conn, 200)
      assert incident_json["fingerprint"] != nil
      assert incident_json["title"] != nil
      assert incident_json["severity"] != nil
      assert meta["page"] == 1
      assert meta["per_page"] == 20
      assert meta["total"] == 1
      assert meta["total_pages"] == 1
    end

    test "returns empty list when no incidents exist", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/incidents")

      assert %{"data" => [], "meta" => meta} = json_response(conn, 200)
      assert meta["page"] == 1
      assert meta["total"] == 0
    end

    test "filters by status", %{conn: conn, account: account, user: user, project: project} do
      incident = incident_fixture(account, user, project)

      conn = get(conn, ~p"/api/v1/incidents?status=unresolved")
      assert %{"data" => [_]} = json_response(conn, 200)

      {:ok, _} = Tracking.resolve_incident(incident)

      conn = get(conn, ~p"/api/v1/incidents?status=unresolved")
      assert %{"data" => []} = json_response(conn, 200)

      conn = get(conn, ~p"/api/v1/incidents?status=resolved")
      assert %{"data" => [_]} = json_response(conn, 200)
    end

    test "filters by severity", %{conn: conn, account: account, user: user, project: project} do
      _incident = incident_fixture(account, user, project, %{severity: :critical})

      conn = get(conn, ~p"/api/v1/incidents?severity=critical")
      assert %{"data" => [_]} = json_response(conn, 200)

      conn = get(conn, ~p"/api/v1/incidents?severity=info")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "filters by muted", %{conn: conn, account: account, user: user, project: project} do
      _incident = incident_fixture(account, user, project)

      conn = get(conn, ~p"/api/v1/incidents?muted=true")
      assert %{"data" => []} = json_response(conn, 200)

      conn = get(conn, ~p"/api/v1/incidents?muted=false")
      assert %{"data" => [_]} = json_response(conn, 200)
    end

    test "filters by source", %{conn: conn, account: account, user: user, project: project} do
      _incident = incident_fixture(account, user, project, %{source: "api-gateway"})

      conn = get(conn, ~p"/api/v1/incidents?source=api-gateway")
      assert %{"data" => [_]} = json_response(conn, 200)

      conn = get(conn, ~p"/api/v1/incidents?source=other")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "does not list incidents from other accounts", %{conn: conn} do
      {other_user, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)
      _other_incident = incident_fixture(other_account, other_user, other_project)

      conn = get(conn, ~p"/api/v1/incidents")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns 401 without authentication", %{conn: conn} do
      conn =
        conn
        |> delete_req_header("authorization")
        |> get(~p"/api/v1/incidents")

      assert json_response(conn, 401)
    end
  end

  describe "show" do
    test "returns incident by id with occurrences", %{
      conn: conn,
      account: account,
      user: user,
      project: project
    } do
      incident = incident_fixture(account, user, project)

      conn = get(conn, ~p"/api/v1/incidents/#{incident.id}")
      assert %{"data" => json} = json_response(conn, 200)
      assert json["id"] == incident.id
      assert json["fingerprint"] == incident.fingerprint
      assert json["title"] == incident.title
      assert is_list(json["occurrences"])
      assert json["occurrence_count"] >= 1
    end

    test "returns 404 for non-existent incident", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/incidents/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end

    test "returns 404 for incident from different account", %{conn: conn} do
      {other_user, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)
      other_incident = incident_fixture(other_account, other_user, other_project)

      conn = get(conn, ~p"/api/v1/incidents/#{other_incident.id}")
      assert json_response(conn, 404)
    end

    test "returns 404 for malformed UUID", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/incidents/not-a-uuid")
      assert json_response(conn, 404)
    end
  end

  describe "create" do
    test "creates new incident with 201 status", %{conn: conn, project: project} do
      params = %{
        project_id: project.id,
        fingerprint: "new_incident_fp",
        title: "Service Down",
        severity: "critical",
        source: "monitoring",
        metadata: %{region: "us-east-1"},
        context: %{request_id: "abc123"}
      }

      conn = post(conn, ~p"/api/v1/incidents", params)
      assert %{"data" => json} = json_response(conn, 201)
      assert json["fingerprint"] == "new_incident_fp"
      assert json["title"] == "Service Down"
      assert json["severity"] == "critical"
      assert json["source"] == "monitoring"
      assert json["status"] == "unresolved"
    end

    test "adds occurrence to existing incident with 200 status", %{
      conn: conn,
      account: account,
      user: user,
      project: project
    } do
      existing = incident_fixture(account, user, project, %{fingerprint: "existing_fp"})

      params = %{
        project_id: project.id,
        fingerprint: "existing_fp",
        title: existing.title,
        severity: "warning",
        source: "test-service",
        context: %{retry: true}
      }

      conn = post(conn, ~p"/api/v1/incidents", params)
      assert %{"data" => json} = json_response(conn, 200)
      assert json["id"] == existing.id
    end

    test "returns 404 for non-existent project", %{conn: conn} do
      params = %{
        project_id: Ecto.UUID.generate(),
        fingerprint: "test_fp",
        title: "Test",
        severity: "info",
        source: "test"
      }

      conn = post(conn, ~p"/api/v1/incidents", params)
      assert json_response(conn, 404)
    end

    test "returns 404 for project from different account", %{conn: conn} do
      {_other_user, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)

      params = %{
        project_id: other_project.id,
        fingerprint: "test_fp",
        title: "Test",
        severity: "info",
        source: "test"
      }

      conn = post(conn, ~p"/api/v1/incidents", params)
      assert json_response(conn, 404)
    end

    test "returns 403 with read-only API key", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      {read_only_token, _api_key} = api_key_fixture(user, account, :public)

      params = %{
        project_id: project.id,
        fingerprint: "test_fp",
        title: "Test",
        severity: "info",
        source: "test"
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{read_only_token}")
        |> post(~p"/api/v1/incidents", params)

      assert json_response(conn, 403)
    end

    test "validates context size limit", %{conn: conn, project: project} do
      params = %{
        project_id: project.id,
        fingerprint: "test_fp",
        title: "Test",
        severity: "info",
        source: "test",
        context: Map.new(1..51, fn i -> {"key_#{i}", "value"} end)
      }

      conn = post(conn, ~p"/api/v1/incidents", params)
      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["context"] != nil
    end
  end

  describe "update" do
    test "updates incident muted flag", %{
      conn: conn,
      account: account,
      user: user,
      project: project
    } do
      incident = incident_fixture(account, user, project)

      conn = patch(conn, ~p"/api/v1/incidents/#{incident.id}", %{muted: true})
      assert %{"data" => json} = json_response(conn, 200)
      assert json["muted"] == true
    end

    test "rejects status update with 400", %{
      conn: conn,
      account: account,
      user: user,
      project: project
    } do
      incident = incident_fixture(account, user, project)

      conn = patch(conn, ~p"/api/v1/incidents/#{incident.id}", %{status: "resolved"})
      assert json_response(conn, 400)
    end

    test "returns 404 for non-existent incident", %{conn: conn} do
      conn = patch(conn, ~p"/api/v1/incidents/#{Ecto.UUID.generate()}", %{muted: true})
      assert json_response(conn, 404)
    end

    test "returns 404 for incident from different account", %{conn: conn} do
      {other_user, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)
      other_incident = incident_fixture(other_account, other_user, other_project)

      conn = patch(conn, ~p"/api/v1/incidents/#{other_incident.id}", %{muted: true})
      assert json_response(conn, 404)
    end

    test "returns 403 with read-only API key", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      incident = incident_fixture(account, user, project)
      {read_only_token, _api_key} = api_key_fixture(user, account, :public)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{read_only_token}")
        |> patch(~p"/api/v1/incidents/#{incident.id}", %{muted: true})

      assert json_response(conn, 403)
    end
  end
end
