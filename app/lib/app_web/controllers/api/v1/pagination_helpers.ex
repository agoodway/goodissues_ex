defmodule FFWeb.Api.V1.PaginationHelpers do
  @moduledoc false

  @doc """
  Validates `page` and `per_page` query parameters.

  Returns `:ok` if valid or absent, `{:error, :bad_request, message}` if invalid.
  """
  def validate_pagination(params) do
    with :ok <- validate_param(params["page"], "page"),
         :ok <- validate_param(params["per_page"], "per_page") do
      :ok
    end
  end

  defp validate_param(nil, _name), do: :ok

  defp validate_param(value, name) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> :ok
      _ -> {:error, :bad_request, "Invalid #{name} parameter: must be a positive integer"}
    end
  end

  defp validate_param(_value, _name), do: :ok
end
