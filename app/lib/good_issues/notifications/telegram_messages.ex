defmodule GI.Notifications.TelegramMessages do
  @moduledoc """
  Builds MarkdownV2-formatted Telegram messages for GoodIssues event types.
  """

  @telegram_special_chars ~r/([_*\[\]()~`>#+\-=|{}.!\\])/

  @doc "Escape text for Telegram MarkdownV2."
  def escape_markdown(nil), do: ""

  def escape_markdown(text) when is_binary(text) do
    Regex.replace(@telegram_special_chars, text, "\\\\\\1")
  end

  @doc "Build a Telegram message for the given event type and data."
  def build(event_type, data) do
    case event_type do
      "issue_created" -> issue_created(data)
      "issue_updated" -> issue_updated(data)
      "issue_status_changed" -> issue_status_changed(data)
      "error_occurred" -> error_occurred(data)
      "error_resolved" -> error_resolved(data)
      other -> fallback(other, data)
    end
  end

  defp issue_created(data) do
    title = escape_markdown(data["title"] || data[:title] || "Untitled")
    project = escape_markdown(data["project_name"] || data[:project_name] || "")
    key = escape_markdown(data["issue_key"] || data[:issue_key] || "")

    """
    🔔 *GoodIssues*

    *New Issue Created*
    #{if key != "", do: "Key: `#{key}`\n", else: ""}Title: #{title}#{if project != "", do: "\nProject: #{project}", else: ""}
    """
    |> String.trim()
  end

  defp issue_updated(data) do
    title = escape_markdown(data["title"] || data[:title] || "Untitled")
    key = escape_markdown(data["issue_key"] || data[:issue_key] || "")

    changes =
      case data["changes"] || data[:changes] do
        changes when is_map(changes) ->
          changes
          |> Enum.map(fn {field, value} ->
            "  • #{escape_markdown(to_string(field))}: #{escape_markdown(to_string(value))}"
          end)
          |> Enum.join("\n")

        _ ->
          ""
      end

    """
    📝 *GoodIssues*

    *Issue Updated*
    #{if key != "", do: "Key: `#{key}`\n", else: ""}Title: #{title}#{if changes != "", do: "\nChanges:\n#{changes}", else: ""}
    """
    |> String.trim()
  end

  defp issue_status_changed(data) do
    title = escape_markdown(data["title"] || data[:title] || "Untitled")
    key = escape_markdown(data["issue_key"] || data[:issue_key] || "")
    old_status = escape_markdown(data["old_status"] || data[:old_status] || "unknown")
    new_status = escape_markdown(data["new_status"] || data[:new_status] || "unknown")

    """
    🔄 *GoodIssues*

    *Issue Status Changed*
    #{if key != "", do: "Key: `#{key}`\n", else: ""}Title: #{title}
    Status: #{old_status} → #{new_status}
    """
    |> String.trim()
  end

  defp error_occurred(data) do
    kind = escape_markdown(data["kind"] || data[:kind] || "Unknown")
    reason = escape_markdown(data["reason"] || data[:reason] || "")
    source = escape_markdown(data["source_line"] || data[:source_line] || "")

    """
    🚨 *GoodIssues*

    *Error Occurred*
    Kind: `#{kind}`#{if reason != "", do: "\nReason: #{reason}", else: ""}#{if source != "", do: "\nSource: `#{source}`", else: ""}
    """
    |> String.trim()
  end

  defp error_resolved(data) do
    kind = escape_markdown(data["kind"] || data[:kind] || "Unknown")

    """
    ✅ *GoodIssues*

    *Error Resolved*
    Kind: `#{kind}`
    """
    |> String.trim()
  end

  defp fallback(event_type, _data) do
    type = escape_markdown(event_type)

    """
    🔔 *GoodIssues*

    *Event: #{type}*
    """
    |> String.trim()
  end
end
