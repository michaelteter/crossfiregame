defmodule CrossfireWeb.Plugs.LogSessionInfo do
  import Plug.Conn

  require Crossfire.Core.Util, as: CU

  def init(default), do: default

  def call(conn, _default) do
    session_info = get_session(conn)
    CU.lfi("Session Information: #{inspect(session_info)}")
    player_id = get_session(conn, :player_id)
    CU.lfi("Player ID: #{inspect(player_id)}")

    conn
  end
end
