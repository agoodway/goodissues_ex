defmodule FFWeb.Api.V1.IssueControllerTest do
  use FFWeb.ConnCase

  import FF.AccountsFixtures
  import FF.TrackingFixtures

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
    test "lists all issues for account", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      issue = issue_fixture(account, user, project)

      conn = get(conn, ~p"/api/v1/issues")

      assert %{"data" => [issue_json], "meta" => meta} = json_response(conn, 200)
      assert issue_json["id"] == issue.id
      assert issue_json["title"] == issue.title
      assert meta["page"] == 1
      assert meta["per_page"] == 20
      assert meta["total"] == 1
      assert meta["total_pages"] == 1
    end

    test "returns empty list when no issues exist", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/issues")

      assert %{"data" => [], "meta" => meta} = json_response(conn, 200)
      assert meta["page"] == 1
      assert meta["total"] == 0
      assert meta["total_pages"] == 1
    end

    test "does not list issues from other accounts", %{conn: conn} do
      {other_user, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)
      _other_issue = issue_fixture(other_account, other_user, other_project)

      conn = get(conn, ~p"/api/v1/issues")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "filters by project_id", %{conn: conn, user: user, account: account, project: project} do
      project2 = project_fixture(account)
      issue1 = issue_fixture(account, user, project)
      _issue2 = issue_fixture(account, user, project2)

      conn = get(conn, ~p"/api/v1/issues?project_id=#{project.id}")
      assert %{"data" => [issue_json]} = json_response(conn, 200)
      assert issue_json["id"] == issue1.id
    end

    test "filters by status", %{conn: conn, user: user, account: account, project: project} do
      issue_new = issue_fixture(account, user, project, %{status: :new})
      _issue_in_progress = issue_fixture(account, user, project, %{status: :in_progress})

      conn = get(conn, ~p"/api/v1/issues?status=new")
      assert %{"data" => [issue_json]} = json_response(conn, 200)
      assert issue_json["id"] == issue_new.id
    end

    test "filters by type", %{conn: conn, user: user, account: account, project: project} do
      issue_bug = issue_fixture(account, user, project, %{type: :bug})
      _issue_feature = issue_fixture(account, user, project, %{type: :feature_request})

      conn = get(conn, ~p"/api/v1/issues?type=bug")
      assert %{"data" => [issue_json]} = json_response(conn, 200)
      assert issue_json["id"] == issue_bug.id
    end

    test "filters by multiple criteria", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      issue_match = issue_fixture(account, user, project, %{type: :bug, status: :new})

      _issue_wrong_type =
        issue_fixture(account, user, project, %{type: :feature_request, status: :new})

      _issue_wrong_status =
        issue_fixture(account, user, project, %{type: :bug, status: :in_progress})

      conn = get(conn, ~p"/api/v1/issues?project_id=#{project.id}&type=bug&status=new")
      assert %{"data" => [issue_json]} = json_response(conn, 200)
      assert issue_json["id"] == issue_match.id
    end

    test "returns 401 without authentication", %{conn: conn} do
      conn =
        conn
        |> delete_req_header("authorization")
        |> get(~p"/api/v1/issues")

      assert json_response(conn, 401)
    end

    test "allows read-only API key to list issues", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      issue = issue_fixture(account, user, project)
      {read_only_token, _api_key} = api_key_fixture(user, account, :public)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{read_only_token}")
        |> get(~p"/api/v1/issues")

      assert %{"data" => [issue_json]} = json_response(conn, 200)
      assert issue_json["id"] == issue.id
    end

    test "ignores invalid status filter values", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      issue = issue_fixture(account, user, project, %{status: :new})

      conn = get(conn, ~p"/api/v1/issues?status=invalid_status")
      assert %{"data" => issues} = json_response(conn, 200)
      assert length(issues) == 1
      assert hd(issues)["id"] == issue.id
    end

    test "ignores invalid type filter values", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      issue = issue_fixture(account, user, project, %{type: :bug})

      conn = get(conn, ~p"/api/v1/issues?type=invalid_type")
      assert %{"data" => issues} = json_response(conn, 200)
      assert length(issues) == 1
      assert hd(issues)["id"] == issue.id
    end

    test "ignores invalid UUID in project_id filter", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      issue = issue_fixture(account, user, project)

      conn = get(conn, ~p"/api/v1/issues?project_id=not-a-uuid")
      assert %{"data" => issues} = json_response(conn, 200)
      assert length(issues) == 1
      assert hd(issues)["id"] == issue.id
    end
  end

  describe "show" do
    test "returns issue by id", %{conn: conn, user: user, account: account, project: project} do
      issue = issue_fixture(account, user, project)

      conn = get(conn, ~p"/api/v1/issues/#{issue.id}")
      assert %{"data" => json} = json_response(conn, 200)
      assert json["id"] == issue.id
      assert json["title"] == issue.title
      assert json["description"] == issue.description
      assert json["type"] == to_string(issue.type)
      assert json["status"] == to_string(issue.status)
      assert json["priority"] == to_string(issue.priority)
      assert json["project_id"] == issue.project_id
      assert json["submitter_id"] == issue.submitter_id
    end

    test "returns 404 for non-existent issue", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/issues/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end

    test "returns 404 for issue from different account", %{conn: conn} do
      {other_user, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)
      other_issue = issue_fixture(other_account, other_user, other_project)

      conn = get(conn, ~p"/api/v1/issues/#{other_issue.id}")
      assert json_response(conn, 404)
    end

    test "returns 404 for invalid UUID", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/issues/not-a-valid-uuid")
      assert json_response(conn, 404)
    end

    test "allows read-only API key to show issue", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      issue = issue_fixture(account, user, project)
      {read_only_token, _api_key} = api_key_fixture(user, account, :public)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{read_only_token}")
        |> get(~p"/api/v1/issues/#{issue.id}")

      assert %{"data" => json} = json_response(conn, 200)
      assert json["id"] == issue.id
    end
  end

  describe "create" do
    test "creates issue with valid params", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      params = %{
        title: "New Bug",
        description: "Something is broken",
        type: "bug",
        priority: "high",
        project_id: project.id
      }

      conn = post(conn, ~p"/api/v1/issues", params)
      assert %{"data" => %{"id" => id}} = json_response(conn, 201)

      issue = FF.Tracking.get_issue(account, id)
      assert issue.title == "New Bug"
      assert issue.description == "Something is broken"
      assert issue.type == :bug
      assert issue.priority == :high
      assert issue.status == :new
      assert issue.submitter_id == user.id
    end

    test "creates issue with minimal params", %{conn: conn, account: account, project: project} do
      params = %{
        title: "Minimal Bug",
        type: "bug",
        project_id: project.id
      }

      conn = post(conn, ~p"/api/v1/issues", params)
      assert %{"data" => %{"id" => id}} = json_response(conn, 201)

      issue = FF.Tracking.get_issue(account, id)
      assert issue.title == "Minimal Bug"
      assert issue.type == :bug
      assert issue.status == :new
      assert issue.priority == :medium
    end

    test "creates issue with submitter_email", %{conn: conn, account: account, project: project} do
      params = %{
        title: "Bug",
        type: "bug",
        project_id: project.id,
        submitter_email: "external@example.com"
      }

      conn = post(conn, ~p"/api/v1/issues", params)
      assert %{"data" => %{"id" => id}} = json_response(conn, 201)

      issue = FF.Tracking.get_issue(account, id)
      assert issue.submitter_email == "external@example.com"
    end

    test "returns error for missing title", %{conn: conn, project: project} do
      params = %{type: "bug", project_id: project.id}

      conn = post(conn, ~p"/api/v1/issues", params)
      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["title"] != nil
    end

    test "returns error for missing type", %{conn: conn, project: project} do
      params = %{title: "Bug", project_id: project.id}

      conn = post(conn, ~p"/api/v1/issues", params)
      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["type"] != nil
    end

    test "returns error for non-existent project", %{conn: conn} do
      params = %{
        title: "Bug",
        type: "bug",
        project_id: Ecto.UUID.generate()
      }

      conn = post(conn, ~p"/api/v1/issues", params)
      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["project_id"] != nil
    end

    test "returns error for project from different account", %{conn: conn} do
      {_other_user, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)

      params = %{
        title: "Bug",
        type: "bug",
        project_id: other_project.id
      }

      conn = post(conn, ~p"/api/v1/issues", params)
      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["project_id"] != nil
    end

    test "returns error for invalid submitter_email format", %{conn: conn, project: project} do
      params = %{
        title: "Bug",
        type: "bug",
        project_id: project.id,
        submitter_email: "not-an-email"
      }

      conn = post(conn, ~p"/api/v1/issues", params)
      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["submitter_email"] != nil
    end

    test "returns error for description too long", %{conn: conn, project: project} do
      params = %{
        title: "Bug",
        type: "bug",
        project_id: project.id,
        description: String.duplicate("a", 10_001)
      }

      conn = post(conn, ~p"/api/v1/issues", params)
      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["description"] != nil
    end

    test "returns 403 with read-only API key", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      {read_only_token, _api_key} = api_key_fixture(user, account, :public)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{read_only_token}")
        |> post(~p"/api/v1/issues", %{title: "Test", type: "bug", project_id: project.id})

      assert json_response(conn, 403)
    end
  end

  describe "update" do
    test "updates issue with valid params", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      issue = issue_fixture(account, user, project)
      params = %{title: "Updated Title", description: "Updated description"}

      conn = patch(conn, ~p"/api/v1/issues/#{issue.id}", params)
      assert %{"data" => json} = json_response(conn, 200)
      assert json["title"] == "Updated Title"
      assert json["description"] == "Updated description"
    end

    test "updates only status (partial update)", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      issue = issue_fixture(account, user, project, %{title: "Original Title", status: :new})
      params = %{status: "in_progress"}

      conn = patch(conn, ~p"/api/v1/issues/#{issue.id}", params)
      assert %{"data" => json} = json_response(conn, 200)
      assert json["title"] == "Original Title"
      assert json["status"] == "in_progress"
    end

    test "sets archived_at when status changes to archived", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      issue = issue_fixture(account, user, project, %{status: :new})
      params = %{status: "archived"}

      conn = patch(conn, ~p"/api/v1/issues/#{issue.id}", params)
      assert %{"data" => json} = json_response(conn, 200)
      assert json["status"] == "archived"
      assert json["archived_at"] != nil
    end

    test "clears archived_at when status changes from archived", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      issue = issue_fixture(account, user, project, %{status: :archived})
      params = %{status: "in_progress"}

      conn = patch(conn, ~p"/api/v1/issues/#{issue.id}", params)
      assert %{"data" => json} = json_response(conn, 200)
      assert json["status"] == "in_progress"
      assert json["archived_at"] == nil
    end

    test "can update priority", %{conn: conn, user: user, account: account, project: project} do
      issue = issue_fixture(account, user, project, %{priority: :low})
      params = %{priority: "critical"}

      conn = patch(conn, ~p"/api/v1/issues/#{issue.id}", params)
      assert %{"data" => json} = json_response(conn, 200)
      assert json["priority"] == "critical"
    end

    test "can update type", %{conn: conn, user: user, account: account, project: project} do
      issue = issue_fixture(account, user, project, %{type: :bug})
      params = %{type: "feature_request"}

      conn = patch(conn, ~p"/api/v1/issues/#{issue.id}", params)
      assert %{"data" => json} = json_response(conn, 200)
      assert json["type"] == "feature_request"
    end

    test "returns 403 with read-only API key", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      issue = issue_fixture(account, user, project)
      {read_only_token, _api_key} = api_key_fixture(user, account, :public)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{read_only_token}")
        |> patch(~p"/api/v1/issues/#{issue.id}", %{title: "Test"})

      assert json_response(conn, 403)
    end

    test "returns error for title too long", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      issue = issue_fixture(account, user, project)
      params = %{title: String.duplicate("a", 256)}

      conn = patch(conn, ~p"/api/v1/issues/#{issue.id}", params)
      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "returns 404 for non-existent issue", %{conn: conn} do
      conn = patch(conn, ~p"/api/v1/issues/#{Ecto.UUID.generate()}", %{title: "Test"})
      assert json_response(conn, 404)
    end

    test "returns 404 for issue from different account", %{conn: conn} do
      {other_user, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)
      other_issue = issue_fixture(other_account, other_user, other_project)

      conn = patch(conn, ~p"/api/v1/issues/#{other_issue.id}", %{title: "Test"})
      assert json_response(conn, 404)
    end

    test "returns 404 for invalid UUID", %{conn: conn} do
      conn = patch(conn, ~p"/api/v1/issues/not-a-valid-uuid", %{title: "Test"})
      assert json_response(conn, 404)
    end
  end

  describe "delete" do
    test "deletes issue", %{conn: conn, user: user, account: account, project: project} do
      issue = issue_fixture(account, user, project)

      conn = delete(conn, ~p"/api/v1/issues/#{issue.id}")
      assert response(conn, 204)

      assert FF.Tracking.get_issue(account, issue.id) == nil
    end

    test "returns 404 for non-existent issue", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/issues/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end

    test "returns 404 for issue from different account", %{conn: conn} do
      {other_user, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)
      other_issue = issue_fixture(other_account, other_user, other_project)

      conn = delete(conn, ~p"/api/v1/issues/#{other_issue.id}")
      assert json_response(conn, 404)
    end

    test "returns 403 with read-only API key", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      issue = issue_fixture(account, user, project)
      {read_only_token, _api_key} = api_key_fixture(user, account, :public)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{read_only_token}")
        |> delete(~p"/api/v1/issues/#{issue.id}")

      assert json_response(conn, 403)
    end

    test "returns 404 for invalid UUID", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/issues/not-a-valid-uuid")
      assert json_response(conn, 404)
    end
  end
end
