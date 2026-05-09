defmodule GI.Repo.Migrations.BackfillDefaultAccounts do
  use Ecto.Migration

  import Ecto.Query

  def up do
    # Find all users who don't have any account membership
    users_without_accounts =
      from(u in "users",
        left_join: au in "account_users",
        on: au.user_id == u.id,
        where: is_nil(au.id),
        select: %{id: u.id, email: u.email}
      )
      |> repo().all()

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Enum.each(users_without_accounts, fn user ->
      # Generate slug from email prefix with uniqueness check
      base_slug = generate_base_slug(user.email)
      slug = ensure_unique_slug(base_slug)

      # Create the account
      {1, [%{id: account_id}]} =
        repo().insert_all(
          "accounts",
          [
            %{
              name: "Personal",
              slug: slug,
              status: "active",
              inserted_at: now,
              updated_at: now
            }
          ],
          returning: [:id]
        )

      # Create the account_user membership with owner role
      repo().insert_all("account_users", [
        %{
          account_id: account_id,
          user_id: user.id,
          role: "owner",
          inserted_at: now,
          updated_at: now
        }
      ])
    end)
  end

  def down do
    # This is a data migration - we can't safely reverse it
    # as we'd potentially delete accounts that have been modified
    :ok
  end

  defp generate_base_slug(email) do
    email
    |> String.split("@")
    |> hd()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
    |> then(&"#{&1}-personal")
  end

  defp ensure_unique_slug(slug, attempt \\ 0) do
    candidate = if attempt == 0, do: slug, else: "#{slug}-#{attempt}"

    exists =
      from(a in "accounts", where: a.slug == ^candidate, select: true)
      |> repo().exists?()

    if exists do
      ensure_unique_slug(slug, attempt + 1)
    else
      candidate
    end
  end
end
