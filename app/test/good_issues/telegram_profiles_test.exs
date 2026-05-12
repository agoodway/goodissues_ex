defmodule GI.TelegramProfilesTest do
  use GI.DataCase, async: true

  alias GI.TelegramProfiles
  alias GI.TelegramProfiles.TelegramProfile

  import GI.AccountsFixtures

  setup do
    {_user, account} = user_with_account_fixture()
    %{account: account}
  end

  describe "create_telegram_profile/1" do
    test "creates a profile with valid attrs", %{account: account} do
      attrs = %{account_id: account.id, bot_token: "123456:ABC-DEF"}
      assert {:ok, profile} = TelegramProfiles.create_telegram_profile(attrs)
      assert profile.account_id == account.id
      assert profile.bot_token_encrypted != nil
      assert profile.bot_username == nil
    end

    test "creates a profile with optional username", %{account: account} do
      attrs = %{account_id: account.id, bot_token: "123456:ABC-DEF", bot_username: "@mybot"}
      assert {:ok, profile} = TelegramProfiles.create_telegram_profile(attrs)
      assert profile.bot_username == "mybot"
    end

    test "fails without bot_token", %{account: account} do
      assert {:error, changeset} =
               TelegramProfiles.create_telegram_profile(%{account_id: account.id})

      assert "can't be blank" in errors_on(changeset).bot_token
    end

    test "fails without account_id" do
      assert {:error, changeset} =
               TelegramProfiles.create_telegram_profile(%{bot_token: "123456:ABC-DEF"})

      assert "can't be blank" in errors_on(changeset).account_id
    end

    test "enforces unique account_id", %{account: account} do
      attrs = %{account_id: account.id, bot_token: "123456:ABC-DEF"}
      assert {:ok, _} = TelegramProfiles.create_telegram_profile(attrs)
      assert {:error, changeset} = TelegramProfiles.create_telegram_profile(attrs)
      assert "has already been taken" in errors_on(changeset).account_id
    end
  end

  describe "get_by_account/1" do
    test "returns profile when it exists", %{account: account} do
      {:ok, created} =
        TelegramProfiles.create_telegram_profile(%{
          account_id: account.id,
          bot_token: "123456:ABC-DEF"
        })

      found = TelegramProfiles.get_by_account(account.id)
      assert found.id == created.id
    end

    test "returns nil when no profile exists", %{account: account} do
      assert TelegramProfiles.get_by_account(account.id) == nil
    end
  end

  describe "update_telegram_profile/2" do
    test "updates bot_username", %{account: account} do
      {:ok, profile} =
        TelegramProfiles.create_telegram_profile(%{
          account_id: account.id,
          bot_token: "123456:ABC-DEF"
        })

      assert {:ok, updated} =
               TelegramProfiles.update_telegram_profile(profile, %{bot_username: "newbot"})

      assert updated.bot_username == "newbot"
    end

    test "updates bot_token", %{account: account} do
      {:ok, profile} =
        TelegramProfiles.create_telegram_profile(%{
          account_id: account.id,
          bot_token: "123456:ABC-DEF"
        })

      assert {:ok, updated} =
               TelegramProfiles.update_telegram_profile(profile, %{bot_token: "789:NEW-TOKEN"})

      reloaded = TelegramProfiles.get_by_account(account.id)
      assert reloaded.bot_token_encrypted != profile.bot_token_encrypted
    end
  end

  describe "delete_telegram_profile/1" do
    test "deletes the profile", %{account: account} do
      {:ok, profile} =
        TelegramProfiles.create_telegram_profile(%{
          account_id: account.id,
          bot_token: "123456:ABC-DEF"
        })

      assert {:ok, _} = TelegramProfiles.delete_telegram_profile(profile)
      assert TelegramProfiles.get_by_account(account.id) == nil
    end
  end

  describe "encrypted token persistence" do
    test "decrypts bot_token_encrypted back to original value", %{account: account} do
      token = "123456:ABC-DEF-GHI-ORIGINAL"

      {:ok, _profile} =
        TelegramProfiles.create_telegram_profile(%{account_id: account.id, bot_token: token})

      reloaded = TelegramProfiles.get_by_account(account.id)
      assert reloaded.bot_token_encrypted == token
    end
  end

  describe "TelegramProfile.mask_token/1" do
    test "masks middle of long token" do
      assert TelegramProfile.mask_token("123456:ABCDEF") == "1234*****CDEF"
    end

    test "fully masks short token" do
      assert TelegramProfile.mask_token("short") == "*****"
    end

    test "returns nil for nil" do
      assert TelegramProfile.mask_token(nil) == nil
    end
  end
end
