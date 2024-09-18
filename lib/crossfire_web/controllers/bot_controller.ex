defmodule CrossfireWeb.BotController do
  use CrossfireWeb, :controller

  def index(conn, _params) do
    render(conn, :index, layout: false)
  end
end
