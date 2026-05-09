defmodule GIWeb.UserRegistrationController do
  use GIWeb, :controller

  alias GI.Accounts
  alias GI.Accounts.User

  def new(conn, _params) do
    changeset = Accounts.change_user_email(%User{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    email = user_params["email"]

    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        conn
        |> put_flash(:info, registration_success_message(email))
        |> redirect(to: ~p"/users/log-in")

      {:error, %Ecto.Changeset{} = changeset} ->
        # Check if the only error is email uniqueness - if so, show success to prevent enumeration
        if email_already_taken?(changeset) do
          # Optionally notify existing user that someone tried to register with their email
          # Accounts.deliver_registration_attempt_notification(email)

          conn
          |> put_flash(:info, registration_success_message(email))
          |> redirect(to: ~p"/users/log-in")
        else
          # Other validation errors (format, length) can be shown
          render(conn, :new, changeset: changeset)
        end
    end
  end

  defp registration_success_message(email) do
    "If #{email} is not already registered, you will receive an email with instructions shortly."
  end

  defp email_already_taken?(changeset) do
    changeset.errors
    |> Keyword.get_values(:email)
    |> Enum.any?(fn {msg, opts} ->
      msg == "has already been taken" or opts[:constraint] == :unique
    end)
  end
end
