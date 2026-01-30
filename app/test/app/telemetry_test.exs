defmodule FF.TelemetryTest do
  use FF.DataCase

  import FF.AccountsFixtures
  import FF.TrackingFixtures

  alias FF.Telemetry

  describe "create_spans_batch/3" do
    setup do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      {:ok, account: account, user: user, project: project}
    end

    test "creates multiple spans in batch", %{account: account, project: project} do
      events = [
        %{
          "request_id" => "req-123",
          "event_type" => "phoenix_request",
          "event_name" => "phoenix.endpoint.stop",
          "timestamp" => DateTime.to_iso8601(DateTime.utc_now()),
          "duration_ms" => 42.5,
          "context" => %{"method" => "GET"},
          "measurements" => %{"duration" => 42_500_000}
        },
        %{
          "request_id" => "req-123",
          "event_type" => "ecto_query",
          "event_name" => "app.repo.query",
          "timestamp" => DateTime.to_iso8601(DateTime.utc_now()),
          "duration_ms" => 15.0
        }
      ]

      assert {:ok, 2} = Telemetry.create_spans_batch(account, project.id, events)
    end

    test "returns error for non-existent project", %{account: account} do
      events = [
        %{
          "event_type" => "phoenix_request",
          "event_name" => "test"
        }
      ]

      fake_project_id = Ecto.UUID.generate()

      assert {:error, :project_not_found} =
               Telemetry.create_spans_batch(account, fake_project_id, events)
    end

    test "returns error for project from different account", %{project: project} do
      {_other_user, other_account} = user_with_account_fixture()

      events = [
        %{
          "event_type" => "phoenix_request",
          "event_name" => "test"
        }
      ]

      assert {:error, :project_not_found} =
               Telemetry.create_spans_batch(other_account, project.id, events)
    end

    test "handles empty events list", %{account: account, project: project} do
      assert {:ok, 0} = Telemetry.create_spans_batch(account, project.id, [])
    end

    test "defaults event_type for unknown types", %{account: account, project: project} do
      events = [
        %{
          "event_type" => "unknown_type",
          "event_name" => "test"
        }
      ]

      assert {:ok, 1} = Telemetry.create_spans_batch(account, project.id, events)

      # Should default to phoenix_request
      spans = Telemetry.list_spans(account, project.id)
      assert [span] = spans
      assert span.event_type == :phoenix_request
    end
  end

  describe "list_spans_by_request_id/2" do
    setup do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      {:ok, account: account, user: user, project: project}
    end

    test "returns spans for request_id", %{account: account, project: project} do
      events = [
        %{
          "request_id" => "req-456",
          "event_type" => "phoenix_request",
          "event_name" => "start",
          "timestamp" => DateTime.to_iso8601(~U[2026-01-30 12:00:00Z])
        },
        %{
          "request_id" => "req-456",
          "event_type" => "ecto_query",
          "event_name" => "query",
          "timestamp" => DateTime.to_iso8601(~U[2026-01-30 12:00:01Z])
        },
        %{
          "request_id" => "req-other",
          "event_type" => "phoenix_request",
          "event_name" => "other"
        }
      ]

      {:ok, 3} = Telemetry.create_spans_batch(account, project.id, events)

      spans = Telemetry.list_spans_by_request_id(account, "req-456")
      assert length(spans) == 2
      assert Enum.all?(spans, &(&1.request_id == "req-456"))
    end

    test "returns empty list for non-existent request_id", %{account: account} do
      spans = Telemetry.list_spans_by_request_id(account, "non-existent")
      assert spans == []
    end

    test "does not return spans from different account", %{account: account, project: project} do
      {_other_user, other_account} = user_with_account_fixture()

      events = [
        %{
          "request_id" => "shared-req-id",
          "event_type" => "phoenix_request",
          "event_name" => "test"
        }
      ]

      {:ok, 1} = Telemetry.create_spans_batch(account, project.id, events)

      # Other account should not see these spans
      spans = Telemetry.list_spans_by_request_id(other_account, "shared-req-id")
      assert spans == []
    end
  end

  describe "list_spans/3" do
    setup do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      {:ok, account: account, user: user, project: project}
    end

    test "returns spans for project", %{account: account, project: project} do
      events = [
        %{"event_type" => "phoenix_request", "event_name" => "one"},
        %{"event_type" => "ecto_query", "event_name" => "two"}
      ]

      {:ok, 2} = Telemetry.create_spans_batch(account, project.id, events)

      spans = Telemetry.list_spans(account, project.id)
      assert length(spans) == 2
    end

    test "respects limit option", %{account: account, project: project} do
      events =
        Enum.map(1..10, fn i ->
          %{"event_type" => "phoenix_request", "event_name" => "event-#{i}"}
        end)

      {:ok, 10} = Telemetry.create_spans_batch(account, project.id, events)

      spans = Telemetry.list_spans(account, project.id, limit: 5)
      assert length(spans) == 5
    end

    test "filters by event_type", %{account: account, project: project} do
      events = [
        %{"event_type" => "phoenix_request", "event_name" => "request"},
        %{"event_type" => "ecto_query", "event_name" => "query"},
        %{"event_type" => "phoenix_error", "event_name" => "error"}
      ]

      {:ok, 3} = Telemetry.create_spans_batch(account, project.id, events)

      spans = Telemetry.list_spans(account, project.id, event_type: :ecto_query)
      assert length(spans) == 1
      assert hd(spans).event_type == :ecto_query
    end
  end

  describe "get_span/2" do
    setup do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      {:ok, account: account, user: user, project: project}
    end

    test "returns span by id", %{account: account, project: project} do
      events = [
        %{"event_type" => "phoenix_request", "event_name" => "test"}
      ]

      {:ok, 1} = Telemetry.create_spans_batch(account, project.id, events)
      [span] = Telemetry.list_spans(account, project.id)

      found_span = Telemetry.get_span(account, span.id)
      assert found_span.id == span.id
    end

    test "returns nil for non-existent span", %{account: account} do
      assert Telemetry.get_span(account, Ecto.UUID.generate()) == nil
    end

    test "returns nil for span from different account", %{account: account, project: project} do
      {_other_user, other_account} = user_with_account_fixture()

      events = [
        %{"event_type" => "phoenix_request", "event_name" => "test"}
      ]

      {:ok, 1} = Telemetry.create_spans_batch(account, project.id, events)
      [span] = Telemetry.list_spans(account, project.id)

      assert Telemetry.get_span(other_account, span.id) == nil
    end
  end
end
