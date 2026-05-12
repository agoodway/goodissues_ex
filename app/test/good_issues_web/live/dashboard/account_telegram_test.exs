defmodule GIWeb.Dashboard.AccountTelegramTest do
  use GIWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import GI.AccountsFixtures

  alias GI.TelegramProfiles

  describe "Telegram settings (authenticated manager)" do
    setup :register_and_log_in_user_with_account

    test "shows empty Telegram form when no profile exists", %{conn: conn, account: account} do
      {:ok, _live, html} = live(conn, ~p"/dashboard/#{account.slug}")
      assert html =~ "Telegram Integration"
      assert html =~ "Bot Token"
    end

    test "creates Telegram profile", %{conn: conn, account: account} do
      {:ok, live_view, _html} = live(conn, ~p"/dashboard/#{account.slug}")

      live_view
      |> form("[phx-submit=save_telegram]",
        telegram_profile: %{bot_token: "123456:ABC-DEF", bot_username: "testbot"}
      )
      |> render_submit()

      assert render(live_view) =~ "Telegram profile created"
      assert TelegramProfiles.get_by_account(account.id) != nil
    end

    test "shows existing Telegram profile", %{conn: conn, account: account} do
      TelegramProfiles.create_telegram_profile(%{
        account_id: account.id,
        bot_token: "123456:ABC-DEF",
        bot_username: "mybot"
      })

      {:ok, _live, html} = live(conn, ~p"/dashboard/#{account.slug}")
      assert html =~ "@mybot"
      assert html =~ "1234"
    end

    test "deletes Telegram profile", %{conn: conn, account: account} do
      TelegramProfiles.create_telegram_profile(%{
        account_id: account.id,
        bot_token: "123456:ABC-DEF"
      })

      {:ok, live_view, _html} = live(conn, ~p"/dashboard/#{account.slug}")

      live_view
      |> element("button[phx-click=delete_telegram]")
      |> render_click()

      assert render(live_view) =~ "Telegram profile removed"
      assert TelegramProfiles.get_by_account(account.id) == nil
    end
  end
end
