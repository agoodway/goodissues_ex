# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Idempotent — safe to run multiple times.

alias GI.Accounts
alias GI.Accounts.User
alias GI.Repo
alias GI.Tracking

seed_users = [
  %{
    email: "admin@goodissues.dev",
    password: "password123456",
    account_name: "GoodIssues",
    project: %{name: "GoodIssues Core", prefix: "GI"}
  },
  %{
    email: "dev@goodissues.dev",
    password: "password123456",
    account_name: "Dev Team",
    project: %{name: "API Service", prefix: "API"}
  },
  %{
    email: "demo@goodissues.dev",
    password: "password123456",
    account_name: "Demo Corp",
    project: nil
  }
]

for seed <- seed_users do
  case Repo.get_by(User, email: seed.email) do
    nil ->
      IO.puts("Creating user #{seed.email}...")

      # Register user (creates default "Personal" account)
      {:ok, user} = Accounts.register_user(%{email: seed.email})

      # Confirm the user
      user
      |> User.confirm_changeset()
      |> Repo.update!()

      # Set password
      {:ok, {user, _tokens}} =
        Accounts.update_user_password(user, %{password: seed.password})

      # Create a named account
      {:ok, account} =
        Accounts.create_account(user, %{name: seed.account_name})

      # Create an API key on the named account
      account_user = Accounts.get_account_user(user, account)

      {:ok, {_api_key, token}} =
        Accounts.create_api_key(account_user, %{name: "Seed Key", type: :private})

      IO.puts("  Account: #{seed.account_name}")
      IO.puts("  API Key: #{token}")

      # Create a project if specified
      if seed.project do
        {:ok, project} = Tracking.create_project(account, seed.project)
        IO.puts("  Project: #{project.name} (#{project.prefix})")
      end

      IO.puts("")

    _user ->
      IO.puts("User #{seed.email} already exists, skipping.")
  end
end

IO.puts("Seeds complete!")
