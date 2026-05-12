defmodule GI.Notifications.TelegramMessagesTest do
  use ExUnit.Case, async: true

  alias GI.Notifications.TelegramMessages

  describe "escape_markdown/1" do
    test "escapes all MarkdownV2 special characters" do
      input = "_*[]()~`>#+-=|{}.!\\"
      escaped = TelegramMessages.escape_markdown(input)

      for char <- String.graphemes(input) do
        assert String.contains?(escaped, "\\#{char}")
      end
    end

    test "leaves normal text unchanged" do
      assert TelegramMessages.escape_markdown("hello world") == "hello world"
    end

    test "returns empty string for nil" do
      assert TelegramMessages.escape_markdown(nil) == ""
    end
  end

  describe "build/2" do
    test "builds issue_created message" do
      msg =
        TelegramMessages.build("issue_created", %{
          "title" => "Login broken",
          "project_name" => "MyApp",
          "issue_key" => "MA-1"
        })

      assert msg =~ "GoodIssues"
      assert msg =~ "New Issue Created"
      assert msg =~ "Login broken"
      assert msg =~ "MyApp"
      assert msg =~ "MA\\-1"
    end

    test "builds issue_updated message" do
      msg =
        TelegramMessages.build("issue_updated", %{
          "title" => "Login broken",
          "changes" => %{"status" => "in_progress"}
        })

      assert msg =~ "Issue Updated"
      assert msg =~ "Login broken"
      assert msg =~ "status"
    end

    test "builds issue_status_changed message" do
      msg =
        TelegramMessages.build("issue_status_changed", %{
          "title" => "Login broken",
          "old_status" => "new",
          "new_status" => "in_progress"
        })

      assert msg =~ "Status Changed"
      assert msg =~ "new → in\\_progress"
    end

    test "builds error_occurred message" do
      msg =
        TelegramMessages.build("error_occurred", %{
          "kind" => "RuntimeError",
          "reason" => "something went wrong",
          "source_line" => "lib/app.ex:42"
        })

      assert msg =~ "Error Occurred"
      assert msg =~ "RuntimeError"
      assert msg =~ "something went wrong"
    end

    test "builds error_resolved message" do
      msg = TelegramMessages.build("error_resolved", %{"kind" => "RuntimeError"})
      assert msg =~ "Error Resolved"
      assert msg =~ "RuntimeError"
    end

    test "builds fallback for unknown event type" do
      msg = TelegramMessages.build("custom_event", %{})
      assert msg =~ "GoodIssues"
      assert msg =~ "custom\\_event"
    end

    test "escapes special characters in dynamic data" do
      msg =
        TelegramMessages.build("issue_created", %{
          "title" => "Fix [urgent] (prod) bug #1"
        })

      assert msg =~ "Fix \\[urgent\\] \\(prod\\) bug \\#1"
    end
  end
end
