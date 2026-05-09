defmodule GIWeb.UserSessionHTML do
  use GIWeb, :html

  embed_templates "user_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:good_issues, GI.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
