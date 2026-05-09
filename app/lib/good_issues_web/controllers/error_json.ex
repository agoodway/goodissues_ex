defmodule GIWeb.ErrorJSON do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on JSON requests.

  See config/config.exs.
  """
  alias OpenApiSpex.Schema
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Error",
    description: "Error response",
    type: :object,
    properties: %{
      errors: %Schema{
        type: :object,
        properties: %{
          detail: %Schema{type: :string, description: "Error message"}
        },
        required: [:detail]
      }
    },
    required: [:errors],
    example: %{
      "errors" => %{
        "detail" => "Not Found"
      }
    }
  })

  def render("400.json", %{message: message}) do
    %{errors: %{detail: message}}
  end

  def render("401.json", _assigns) do
    %{errors: %{detail: "Unauthorized - valid API key required"}}
  end

  def render("403.json", _assigns) do
    %{errors: %{detail: "Forbidden - insufficient permissions"}}
  end

  def render("forbidden_scope.json", %{scope: scope}) do
    %{errors: %{detail: "Forbidden - missing required scope: #{scope}"}}
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
