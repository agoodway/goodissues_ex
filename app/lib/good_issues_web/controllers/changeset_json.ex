defmodule GIWeb.ChangesetJSON do
  @moduledoc """
  Renders changeset errors as JSON.
  """
  alias OpenApiSpex.Schema
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "ValidationError",
    description: "Validation error response",
    type: :object,
    properties: %{
      errors: %Schema{
        type: :object,
        additionalProperties: %Schema{
          type: :array,
          items: %Schema{type: :string}
        },
        description: "Map of field names to error messages"
      }
    },
    required: [:errors],
    example: %{
      "errors" => %{
        "name" => ["can't be blank"],
        "email" => ["has invalid format"]
      }
    }
  })

  def error(%{changeset: changeset}) do
    %{errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)}
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
