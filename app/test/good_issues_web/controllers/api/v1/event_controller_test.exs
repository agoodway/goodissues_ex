defmodule GIWeb.Api.V1.EventControllerTest do
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

  describe "create_batch" do
    test "creates multiple events successfully", %{conn: conn, project: project} do
      events = [
        %{
          project_id: project.id,
          request_id: "req-123",
          event_type: "phoenix_request",
          event_name: "phoenix.endpoint.stop",
          timestamp: DateTime.to_iso8601(DateTime.utc_now()),
          duration_ms: 42.5,
          context: %{method: "GET", path: "/users"},
          measurements: %{duration_ms: 42.5}
        },
        %{
          project_id: project.id,
          request_id: "req-123",
          event_type: "ecto_query",
          event_name: "my_app.repo.query",
          timestamp: DateTime.to_iso8601(DateTime.utc_now()),
          duration_ms: 15.0,
          context: %{query: "SELECT * FROM users"},
          measurements: %{total_time_ms: 15.0}
        }
      ]

      conn = post(conn, ~p"/api/v1/events/batch", %{events: events})
      assert %{"inserted" => 2} = json_response(conn, 201)
    end

    test "creates events with minimal fields", %{conn: conn, project: project} do
      events = [
        %{
          project_id: project.id,
          event_type: "phoenix_error",
          event_name: "router_dispatch.exception"
        }
      ]

      conn = post(conn, ~p"/api/v1/events/batch", %{events: events})
      assert %{"inserted" => 1} = json_response(conn, 201)
    end

    test "handles empty events array", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/events/batch", %{events: []})
      assert %{"inserted" => 0} = json_response(conn, 201)
    end

    test "returns errors for invalid project_id", %{conn: conn} do
      events = [
        %{
          project_id: Ecto.UUID.generate(),
          event_type: "phoenix_request",
          event_name: "test"
        }
      ]

      conn = post(conn, ~p"/api/v1/events/batch", %{events: events})
      response = json_response(conn, 201)
      assert response["inserted"] == 0
      assert length(response["errors"]) == 1
    end

    test "returns errors for project from different account", %{conn: conn} do
      {_other_user, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)

      events = [
        %{
          project_id: other_project.id,
          event_type: "phoenix_request",
          event_name: "test"
        }
      ]

      conn = post(conn, ~p"/api/v1/events/batch", %{events: events})
      response = json_response(conn, 201)
      assert response["inserted"] == 0
      assert length(response["errors"]) == 1
    end

    test "handles mixed valid and invalid projects", %{conn: conn, project: project} do
      events = [
        %{
          project_id: project.id,
          event_type: "phoenix_request",
          event_name: "valid"
        },
        %{
          project_id: Ecto.UUID.generate(),
          event_type: "phoenix_request",
          event_name: "invalid project"
        }
      ]

      conn = post(conn, ~p"/api/v1/events/batch", %{events: events})
      response = json_response(conn, 201)
      assert response["inserted"] == 1
      assert length(response["errors"]) == 1
    end

    test "returns 401 without authentication", %{conn: conn, project: project} do
      events = [
        %{
          project_id: project.id,
          event_type: "phoenix_request",
          event_name: "test"
        }
      ]

      conn =
        conn
        |> delete_req_header("authorization")
        |> post(~p"/api/v1/events/batch", %{events: events})

      assert json_response(conn, 401)
    end

    test "returns 403 with read-only API key", %{
      conn: conn,
      user: user,
      account: account,
      project: project
    } do
      {read_only_token, _api_key} = api_key_fixture(user, account, :public)

      events = [
        %{
          project_id: project.id,
          event_type: "phoenix_request",
          event_name: "test"
        }
      ]

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{read_only_token}")
        |> post(~p"/api/v1/events/batch", %{events: events})

      assert json_response(conn, 403)
    end

    test "returns 400 when events is not an array", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/events/batch", %{events: "not an array"})
      assert %{"error" => "events must be an array"} = json_response(conn, 400)
    end

    test "stores all event types correctly", %{conn: conn, project: project} do
      event_types = [
        "phoenix_request",
        "phoenix_router",
        "phoenix_error",
        "liveview_mount",
        "liveview_event",
        "ecto_query"
      ]

      events =
        Enum.map(event_types, fn type ->
          %{
            project_id: project.id,
            event_type: type,
            event_name: "test.#{type}"
          }
        end)

      conn = post(conn, ~p"/api/v1/events/batch", %{events: events})
      assert %{"inserted" => 6} = json_response(conn, 201)
    end

    test "stores request_id and trace_id", %{conn: conn, project: project} do
      events = [
        %{
          project_id: project.id,
          request_id: "req-abc-123",
          trace_id: "trace-xyz-456",
          event_type: "phoenix_request",
          event_name: "test"
        }
      ]

      conn = post(conn, ~p"/api/v1/events/batch", %{events: events})
      assert %{"inserted" => 1} = json_response(conn, 201)

      # Verify data was stored correctly
      [span] = GI.Telemetry.list_spans_by_request_id(conn.assigns.current_account, "req-abc-123")
      assert span.request_id == "req-abc-123"
      assert span.trace_id == "trace-xyz-456"
    end
  end
end
