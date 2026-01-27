defmodule FFWeb.ErrorJSON do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on JSON requests.

  See config/config.exs.
  """

  def render("401.json", _assigns) do
    %{errors: %{detail: "Unauthorized - valid API key required"}}
  end

  def render("403.json", _assigns) do
    %{errors: %{detail: "Forbidden - insufficient permissions"}}
  end

  def render("404.json", _assigns) do
    %{errors: %{detail: "Not Found"}}
  end

  # By default, Phoenix returns the status message from
  # the template name. For example, "500.json" becomes
  # "Internal Server Error".
  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
