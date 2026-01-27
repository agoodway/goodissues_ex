defmodule FFWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid Plug.Conn responses.
  """
  use FFWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: FFWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> put_view(json: FFWeb.ErrorJSON)
    |> render(:"403")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: FFWeb.ErrorJSON)
    |> render(:"401")
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: FFWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end
end
