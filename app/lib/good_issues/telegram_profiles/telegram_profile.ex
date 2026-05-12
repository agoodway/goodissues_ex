defmodule GI.TelegramProfiles.TelegramProfile do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "telegram_profiles" do
    field :bot_token_encrypted, GI.Encrypted.Binary
    field :bot_token, :string, virtual: true, redact: true
    field :bot_username, :string

    belongs_to :account, GI.Accounts.Account

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for creating a new Telegram profile."
  def create_changeset(profile, attrs) do
    profile
    |> cast(attrs, [:bot_token, :bot_username, :account_id])
    |> validate_required([:bot_token, :account_id])
    |> normalize_username()
    |> encrypt_token()
    |> unique_constraint(:account_id)
    |> unique_constraint(:bot_username, name: :telegram_profiles_bot_username_unique)
    |> foreign_key_constraint(:account_id)
  end

  @doc "Changeset for updating an existing Telegram profile."
  def update_changeset(profile, attrs) do
    profile
    |> cast(attrs, [:bot_token, :bot_username])
    |> normalize_username()
    |> maybe_encrypt_token()
    |> unique_constraint(:bot_username, name: :telegram_profiles_bot_username_unique)
  end

  defp normalize_username(changeset) do
    case get_change(changeset, :bot_username) do
      nil -> changeset
      "" -> put_change(changeset, :bot_username, nil)
      username -> put_change(changeset, :bot_username, String.trim_leading(username, "@"))
    end
  end

  defp encrypt_token(changeset) do
    case get_change(changeset, :bot_token) do
      nil -> changeset
      token -> put_change(changeset, :bot_token_encrypted, token)
    end
  end

  defp maybe_encrypt_token(changeset) do
    case get_change(changeset, :bot_token) do
      nil -> changeset
      token when is_binary(token) -> put_change(changeset, :bot_token_encrypted, token)
    end
  end

  @doc "Returns a masked version of the bot token for display."
  def mask_token(nil), do: nil

  def mask_token(token) when is_binary(token) do
    case String.length(token) do
      len when len > 8 ->
        String.slice(token, 0, 4) <> String.duplicate("*", len - 8) <> String.slice(token, -4, 4)

      _ ->
        String.duplicate("*", String.length(token))
    end
  end
end
