defmodule GI.TelegramProfiles do
  @moduledoc "Context for managing per-account Telegram bot profiles."

  alias GI.Repo
  alias GI.TelegramProfiles.TelegramProfile

  @spec get_by_account(String.t()) :: TelegramProfile.t() | nil
  def get_by_account(account_id) do
    Repo.get_by(TelegramProfile, account_id: account_id)
  end

  @spec change_telegram_profile(TelegramProfile.t(), map()) :: Ecto.Changeset.t()
  def change_telegram_profile(%TelegramProfile{} = profile, attrs \\ %{}) do
    if profile.id do
      TelegramProfile.update_changeset(profile, attrs)
    else
      TelegramProfile.create_changeset(profile, attrs)
    end
  end

  @spec create_telegram_profile(map()) ::
          {:ok, TelegramProfile.t()} | {:error, Ecto.Changeset.t()}
  def create_telegram_profile(attrs) do
    %TelegramProfile{}
    |> TelegramProfile.create_changeset(attrs)
    |> Repo.insert()
  end

  @spec update_telegram_profile(TelegramProfile.t(), map()) ::
          {:ok, TelegramProfile.t()} | {:error, Ecto.Changeset.t()}
  def update_telegram_profile(%TelegramProfile{} = profile, attrs) do
    profile
    |> TelegramProfile.update_changeset(attrs)
    |> Repo.update()
  end

  @spec delete_telegram_profile(TelegramProfile.t()) ::
          {:ok, TelegramProfile.t()} | {:error, Ecto.Changeset.t()}
  def delete_telegram_profile(%TelegramProfile{} = profile) do
    Repo.delete(profile)
  end
end
