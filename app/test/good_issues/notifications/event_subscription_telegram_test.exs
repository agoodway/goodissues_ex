defmodule GI.Notifications.EventSubscriptionTelegramTest do
  use GI.DataCase, async: true

  alias GI.Notifications.EventSubscription

  import GI.AccountsFixtures

  setup do
    {_user, account} = user_with_account_fixture()
    %{account: account}
  end

  defp valid_telegram_attrs(account) do
    %{
      account_id: account.id,
      channel: "telegram",
      destination: "123456789",
      event_types: ["issue_created"],
      name: "Telegram test",
      active: true
    }
  end

  describe "Telegram channel validation" do
    test "accepts valid positive chat ID", %{account: account} do
      changeset = EventSubscription.changeset(%EventSubscription{}, valid_telegram_attrs(account))
      assert changeset.valid?
      assert get_field(changeset, :secret) == nil
    end

    test "accepts valid negative chat ID (group)", %{account: account} do
      attrs = valid_telegram_attrs(account) |> Map.put(:destination, "-1001234567890")
      changeset = EventSubscription.changeset(%EventSubscription{}, attrs)
      assert changeset.valid?
    end

    test "rejects non-numeric chat ID", %{account: account} do
      attrs = valid_telegram_attrs(account) |> Map.put(:destination, "not-a-number")
      changeset = EventSubscription.changeset(%EventSubscription{}, attrs)
      refute changeset.valid?
      assert "must be a valid Telegram chat ID (numeric)" in errors_on(changeset).destination
    end

    test "rejects missing destination", %{account: account} do
      attrs = valid_telegram_attrs(account) |> Map.delete(:destination)
      changeset = EventSubscription.changeset(%EventSubscription{}, attrs)
      refute changeset.valid?
    end

    test "rejects user_id for Telegram", %{account: account} do
      attrs =
        valid_telegram_attrs(account)
        |> Map.put(:user_id, Ecto.UUID.generate())
        |> Map.delete(:destination)

      changeset = EventSubscription.changeset(%EventSubscription{}, attrs)
      refute changeset.valid?
      assert "must be blank for Telegram subscriptions" in errors_on(changeset).user_id
    end

    test "clears secret for Telegram subscriptions", %{account: account} do
      changeset = EventSubscription.changeset(%EventSubscription{}, valid_telegram_attrs(account))
      assert get_field(changeset, :secret) == nil
    end
  end
end
