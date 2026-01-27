defmodule FFWeb.PageController do
  use FFWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
