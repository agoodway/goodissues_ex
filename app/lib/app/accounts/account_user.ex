defmodule FF.Accounts.AccountUser do
  @moduledoc """
  Join schema for User <-> Account many-to-many relationship.
  Includes role for authorization within the account.
  API keys belong to this membership (user+account pair).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "account_users" do
    field :role, Ecto.Enum, values: [:owner, :admin, :member], default: :member

    belongs_to :user, FF.Accounts.User
    belongs_to :account, FF.Accounts.Account
    has_many :api_keys, FF.Accounts.ApiKey

    timestamps(type: :utc_datetime)
  end

  def changeset(account_user, attrs) do
    account_user
    |> cast(attrs, [:role, :user_id, :account_id])
    |> validate_required([:user_id, :account_id])
    |> unique_constraint([:user_id, :account_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:account_id)
  end

  @doc "Check if this membership has admin-level access"
  def admin?(%__MODULE__{role: role}), do: role in [:owner, :admin]

  @doc "Check if this membership is the account owner"
  def owner?(%__MODULE__{role: :owner}), do: true
  def owner?(_), do: false
end
