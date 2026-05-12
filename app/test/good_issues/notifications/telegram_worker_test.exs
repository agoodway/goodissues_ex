defmodule GI.Notifications.Workers.TelegramWorkerTest do
  use GI.DataCase, async: false

  alias GI.Notifications
  alias GI.Notifications.Workers.TelegramWorker
  alias GI.TelegramProfiles

  import GI.AccountsFixtures

  setup do
    {_user, account} = user_with_account_fixture()

    {:ok, _profile} =
      TelegramProfiles.create_telegram_profile(%{
        account_id: account.id,
        bot_token: "123456:ABC-DEF"
      })

    {:ok, subscription} =
      Notifications.create_subscription(%{
        account_id: account.id,
        channel: "telegram",
        destination: "123456789",
        event_types: ["issue_created"],
        name: "Test Telegram Sub",
        active: true
      })

    %{account: account, subscription: subscription}
  end

  defp build_args(account, subscription, overrides \\ %{}) do
    Map.merge(
      %{
        "event_id" => Ecto.UUID.generate(),
        "event_type" => "issue_created",
        "event_data" => %{"title" => "Test Issue"},
        "account_id" => account.id,
        "destination" => "123456789",
        "subscription_id" => subscription.id,
        "resource_type" => "issue",
        "resource_id" => Ecto.UUID.generate()
      },
      overrides
    )
  end

  describe "perform/1" do
    test "delivers successfully", %{account: account, subscription: sub} do
      Application.put_env(:good_issues, :telegram_client, GI.Test.TelegramClientSuccess)

      job = %Oban.Job{args: build_args(account, sub)}
      assert :ok = TelegramWorker.perform(job)
    after
      Application.delete_env(:good_issues, :telegram_client)
    end

    test "cancels when no Telegram profile exists" do
      {_user, account2} = user_with_account_fixture()

      {:ok, sub2} =
        Notifications.create_subscription(%{
          account_id: account2.id,
          channel: "telegram",
          destination: "999",
          event_types: ["issue_created"],
          name: "No Profile Sub",
          active: true
        })

      job = %Oban.Job{args: build_args(account2, sub2)}
      assert {:cancel, reason} = TelegramWorker.perform(job)
      assert reason =~ "no Telegram profile"
    end

    test "cancels for invalid chat ID", %{account: account, subscription: sub} do
      args = build_args(account, sub, %{"destination" => "not-a-number"})
      job = %Oban.Job{args: args}
      assert {:cancel, reason} = TelegramWorker.perform(job)
      assert reason =~ "invalid Telegram chat ID"
    end

    test "returns error on Telegram API failure", %{account: account, subscription: sub} do
      Application.put_env(:good_issues, :telegram_client, GI.Test.TelegramClientFailure)

      job = %Oban.Job{args: build_args(account, sub)}
      assert {:error, _reason} = TelegramWorker.perform(job)
    after
      Application.delete_env(:good_issues, :telegram_client)
    end

    test "creates delivery log on success", %{account: account, subscription: sub} do
      Application.put_env(:good_issues, :telegram_client, GI.Test.TelegramClientSuccess)

      job = %Oban.Job{args: build_args(account, sub)}
      TelegramWorker.perform(job)

      logs = Notifications.list_notification_logs(account_id: account.id)
      assert length(logs) == 1
      assert hd(logs).channel == "telegram"
      assert hd(logs).status == "delivered"
    after
      Application.delete_env(:good_issues, :telegram_client)
    end

    test "creates delivery log on failure", %{account: account, subscription: sub} do
      Application.put_env(:good_issues, :telegram_client, GI.Test.TelegramClientFailure)

      job = %Oban.Job{args: build_args(account, sub)}
      TelegramWorker.perform(job)

      logs = Notifications.list_notification_logs(account_id: account.id)
      assert length(logs) == 1
      assert hd(logs).channel == "telegram"
      assert hd(logs).status == "failed"
    after
      Application.delete_env(:good_issues, :telegram_client)
    end
  end
end
