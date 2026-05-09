defmodule GIWeb.Api.V1.ErrorControllerTest do
  use GIWeb.ConnCase

  import GI.AccountsFixtures
  import GI.TrackingFixtures

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
    test "lists all errors for account", %{
      conn: conn,
      account: account,
      user: user,
      project: project
    } do
      issue = issue_fixture(account, user, project)
      error = error_fixture(issue)

      conn = get(conn, ~p"/api/v1/errors")

      assert %{"data" => [error_json], "meta" => meta} = json_response(conn, 200)
      assert error_json["id"] == error.id
      assert error_json["kind"] == error.kind
      assert meta["page"] == 1
      assert meta["per_page"] == 20
      assert meta["total"] == 1
      assert meta["total_pages"] == 1
    end

    test "returns empty list when no errors exist", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/errors")

      assert %{"data" => [], "meta" => meta} = json_response(conn, 200)
      assert meta["page"] == 1
      assert meta["total"] == 0
    end

    test "filters by status", %{conn: conn, account: account, user: user, project: project} do
      issue = issue_fixture(account, user, project)
      error = error_fixture(issue)

      conn = get(conn, ~p"/api/v1/errors?status=unresolved")
      assert %{"data" => [error_json]} = json_response(conn, 200)
      assert error_json["id"] == error.id

      conn = get(conn, ~p"/api/v1/errors?status=resolved")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "filters by muted", %{conn: conn, account: account, user: user, project: project} do
      issue = issue_fixture(account, user, project)
      _error = error_fixture(issue)

      conn = get(conn, ~p"/api/v1/errors?muted=true")
      assert %{"data" => []} = json_response(conn, 200)

      conn = get(conn, ~p"/api/v1/errors?muted=false")
      assert %{"data" => [_]} = json_response(conn, 200)
    end

    test "does not list errors from other accounts", %{conn: conn} do
      {other_user, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)
      other_issue = issue_fixture(other_account, other_user, other_project)
      _other_error = error_fixture(other_issue)

      conn = get(conn, ~p"/api/v1/errors")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns 401 without authentication", %{conn: conn} do
      conn =
        conn
        |> delete_req_header("authorization")
        |> get(~p"/api/v1/errors")

      assert json_response(conn, 401)
    end
  end

  describe "show" do
    test "returns error by id with occurrences", %{
      conn: conn,
      account: account,
      user: user,
      project: project
    } do
      issue = issue_fixture(account, user, project)
      error = error_fixture(issue)

      conn = get(conn, ~p"/api/v1/errors/#{error.id}")
      assert %{"data" => json} = json_response(conn, 200)
      assert json["id"] == error.id
      assert json["kind"] == error.kind
      assert json["reason"] == error.reason
      assert is_list(json["occurrences"])
    end

    test "returns 404 for non-existent error", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/errors/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end

    test "returns 404 for error from different account", %{conn: conn} do
      {other_user, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)
      other_issue = issue_fixture(other_account, other_user, other_project)
      other_error = error_fixture(other_issue)

      conn = get(conn, ~p"/api/v1/errors/#{other_error.id}")
      assert json_response(conn, 404)
    end
  end

  describe "create" do
    test "creates new error with 201 status", %{conn: conn, project: project} do
      fingerprint = unique_fingerprint()

      params = %{
        project_id: project.id,
        kind: "Elixir.RuntimeError",
        reason: "something went wrong",
        fingerprint: fingerprint,
        stacktrace: [
          %{
            module: "MyApp.Worker",
            function: "perform",
            arity: 2,
            file: "lib/worker.ex",
            line: 42
          }
        ]
      }

      conn = post(conn, ~p"/api/v1/errors", params)
      assert %{"data" => json} = json_response(conn, 201)
      assert json["kind"] == "Elixir.RuntimeError"
      assert json["reason"] == "something went wrong"
      assert json["fingerprint"] == fingerprint
    end

    test "adds occurrence to existing error with 200 status", %{
      conn: conn,
      account: account,
      user: user,
      project: project
    } do
      # Create initial error
      issue = issue_fixture(account, user, project)
      existing_error = error_fixture(issue)

      # Report same fingerprint
      params = %{
        project_id: project.id,
        kind: existing_error.kind,
        reason: "new occurrence",
        fingerprint: existing_error.fingerprint,
        context: %{request_id: "new-request"}
      }

      conn = post(conn, ~p"/api/v1/errors", params)
      assert %{"data" => json} = json_response(conn, 200)
      assert json["id"] == existing_error.id
    end

    test "returns 404 for non-existent project", %{conn: conn} do
      params = %{
        project_id: Ecto.UUID.generate(),
        kind: "Elixir.RuntimeError",
        reason: "test",
        fingerprint: unique_fingerprint()
      }

      conn = post(conn, ~p"/api/v1/errors", params)
      assert json_response(conn, 404)
    end

    test "returns 404 for project from different account", %{conn: conn} do
      {_other_user, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)

      params = %{
        project_id: other_project.id,
        kind: "Elixir.RuntimeError",
        reason: "test",
        fingerprint: unique_fingerprint()
      }

      conn = post(conn, ~p"/api/v1/errors", params)
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
        kind: "Elixir.RuntimeError",
        reason: "test",
        fingerprint: unique_fingerprint()
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{read_only_token}")
        |> post(~p"/api/v1/errors", params)

      assert json_response(conn, 403)
    end

    test "validates fingerprint length", %{conn: conn, project: project} do
      params = %{
        project_id: project.id,
        kind: "Elixir.RuntimeError",
        reason: "test",
        fingerprint: "too-short"
      }

      conn = post(conn, ~p"/api/v1/errors", params)
      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["fingerprint"] != nil
    end

    test "validates breadcrumbs limit", %{conn: conn, project: project} do
      params = %{
        project_id: project.id,
        kind: "Elixir.RuntimeError",
        reason: "test",
        fingerprint: unique_fingerprint(),
        breadcrumbs: Enum.map(1..101, &"breadcrumb-#{&1}")
      }

      conn = post(conn, ~p"/api/v1/errors", params)
      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["breadcrumbs"] != nil
    end

    test "validates context size limit", %{conn: conn, project: project} do
      params = %{
        project_id: project.id,
        kind: "Elixir.RuntimeError",
        reason: "test",
        fingerprint: unique_fingerprint(),
        context: Map.new(1..51, fn i -> {"key_#{i}", "value"} end)
      }

      conn = post(conn, ~p"/api/v1/errors", params)
      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["context"] != nil
    end
  end

  describe "update" do
    test "updates error status", %{conn: conn, account: account, user: user, project: project} do
      issue = issue_fixture(account, user, project)
      error = error_fixture(issue)

      conn = patch(conn, ~p"/api/v1/errors/#{error.id}", %{status: "resolved"})
      assert %{"data" => json} = json_response(conn, 200)
      assert json["status"] == "resolved"
    end

    test "updates error muted flag", %{conn: conn, account: account, user: user, project: project} do
      issue = issue_fixture(account, user, project)
      error = error_fixture(issue)

      conn = patch(conn, ~p"/api/v1/errors/#{error.id}", %{muted: true})
      assert %{"data" => json} = json_response(conn, 200)
      assert json["muted"] == true
    end

    test "returns 404 for non-existent error", %{conn: conn} do
      conn = patch(conn, ~p"/api/v1/errors/#{Ecto.UUID.generate()}", %{status: "resolved"})
      assert json_response(conn, 404)
    end

    test "returns 404 for error from different account", %{conn: conn} do
      {other_user, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)
      other_issue = issue_fixture(other_account, other_user, other_project)
      other_error = error_fixture(other_issue)

      conn = patch(conn, ~p"/api/v1/errors/#{other_error.id}", %{status: "resolved"})
      assert json_response(conn, 404)
    end

    test "returns 403 with read-only API key", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      issue = issue_fixture(account, user, project)
      error = error_fixture(issue)
      {read_only_token, _api_key} = api_key_fixture(user, account, :public)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{read_only_token}")
        |> patch(~p"/api/v1/errors/#{error.id}", %{status: "resolved"})

      assert json_response(conn, 403)
    end
  end

  describe "search" do
    test "searches errors by module", %{
      conn: conn,
      account: account,
      user: user,
      project: project
    } do
      issue = issue_fixture(account, user, project)

      _error =
        error_fixture(issue, %{}, %{
          stacktrace_lines: [
            %{
              module: "MyApp.SpecificWorker",
              function: "run",
              arity: 1,
              file: "lib/worker.ex",
              line: 10
            }
          ]
        })

      conn = get(conn, ~p"/api/v1/errors/search?module=MyApp.SpecificWorker")

      assert %{"data" => [error_json], "meta" => meta} = json_response(conn, 200)
      assert error_json != nil
      assert meta["page"] == 1
      assert meta["per_page"] == 20
      assert meta["total"] == 1
      assert meta["total_pages"] == 1
    end

    test "returns empty for non-matching search", %{
      conn: conn,
      account: account,
      user: user,
      project: project
    } do
      issue = issue_fixture(account, user, project)
      _error = error_fixture(issue)

      conn = get(conn, ~p"/api/v1/errors/search?module=NonExistent.Module")

      assert %{"data" => [], "meta" => meta} = json_response(conn, 200)
      assert meta["page"] == 1
      assert meta["total"] == 0
    end
  end
end
