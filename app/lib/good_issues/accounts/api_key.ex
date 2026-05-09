defmodule FF.Accounts.ApiKey do
  @moduledoc """
  Schema for API keys used for programmatic authentication.
  Supports public (read-only) and private (read/write) keys.
  Keys are scoped to a user's membership in an account.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_scopes ~w(
    projects:read projects:write
    checks:read checks:write
    heartbeats:read heartbeats:write
    issues:read issues:write
    errors:read errors:write
    events:read events:write
  )

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          name: String.t() | nil,
          type: :public | :private,
          token_prefix: String.t() | nil,
          token_hash: String.t() | nil,
          status: :active | :revoked,
          scopes: [String.t()],
          last_used_at: DateTime.t() | nil,
          expires_at: DateTime.t() | nil,
          account_user_id: Ecto.UUID.t() | nil,
          account_user: FF.Accounts.AccountUser.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "api_keys" do
    field :name, :string
    field :type, Ecto.Enum, values: [:public, :private], default: :public
    # First 12 chars of token
    field :token_prefix, :string
    # SHA256 hash of full token
    field :token_hash, :string
    field :status, Ecto.Enum, values: [:active, :revoked], default: :active
    field :scopes, {:array, :string}, default: []
    field :last_used_at, :utc_datetime
    field :expires_at, :utc_datetime

    belongs_to :account_user, FF.Accounts.AccountUser

    timestamps(type: :utc_datetime)
  end

  @doc "Check if API key can perform write operations"
  def can_write?(%__MODULE__{type: :private}), do: true
  def can_write?(_), do: false

  @doc "Generate a new API key token"
  def generate_token(type) do
    prefix = if type == :private, do: "sk_", else: "pk_"
    random_bytes = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    prefix <> random_bytes
  end

  @doc "Hash a token for storage"
  def hash_token(token) do
    :crypto.hash(:sha256, token) |> Base.encode64()
  end

  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:name, :type, :scopes, :expires_at, :account_user_id])
    |> validate_required([:name, :type, :account_user_id])
    |> validate_scopes()
    |> foreign_key_constraint(:account_user_id)
  end

  @doc """
  Changeset for updating only scopes.
  Used when editing an existing API key's permissions.
  """
  def scopes_changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:scopes])
    |> validate_scopes()
  end

  @doc "Returns the list of valid scope values"
  def valid_scopes, do: @valid_scopes

  defp validate_scopes(changeset) do
    validate_change(changeset, :scopes, fn :scopes, scopes ->
      invalid_scopes = Enum.reject(scopes, &(&1 in @valid_scopes))

      if invalid_scopes == [] do
        []
      else
        [{:scopes, "contains invalid scopes: #{Enum.join(invalid_scopes, ", ")}"}]
      end
    end)
  end
end
