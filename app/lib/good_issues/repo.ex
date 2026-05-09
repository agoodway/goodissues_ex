defmodule GI.Repo do
  use Ecto.Repo,
    otp_app: :good_issues,
    adapter: Ecto.Adapters.Postgres
end
