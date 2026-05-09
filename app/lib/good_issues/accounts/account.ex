defmodule GI.Accounts.Account do
  @moduledoc """
  Schema for accounts (organizations/tenants).
  Users can belong to multiple accounts.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          name: String.t() | nil,
          slug: String.t() | nil,
          status: :active | :suspended,
          account_users: [GI.Accounts.AccountUser.t()] | Ecto.Association.NotLoaded.t(),
          users: [GI.Accounts.User.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "accounts" do
    field :name, :string
    field :slug, :string
    field :status, Ecto.Enum, values: [:active, :suspended], default: :active

    has_many :account_users, GI.Accounts.AccountUser
    has_many :users, through: [:account_users, :user]

    timestamps(type: :utc_datetime)
  end

  def changeset(account, attrs) do
    account
    |> cast(attrs, [:name, :slug, :status])
    |> validate_required([:name])
    |> unique_constraint(:slug)
    |> maybe_generate_slug()
  end

  defp maybe_generate_slug(changeset) do
    case get_field(changeset, :slug) do
      nil ->
        name = get_field(changeset, :name)

        if name do
          slug = name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")
          put_change(changeset, :slug, slug)
        else
          changeset
        end

      _ ->
        changeset
    end
  end
end
