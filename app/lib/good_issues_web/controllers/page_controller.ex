defmodule GIWeb.PageController do
  use GIWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
