defmodule CrossfireWeb.Plugs.PlayerID do
  import Plug.Conn

  require Crossfire.Core.Util, as: CU

  def init(default), do: default

  def call(conn, _default) do
    # Get the user agent and store it in the session.
    # There is probably a better/more common way of handling this, but our goal is to
    #   use this information to separate human users from web bots.
    # It probably also belongs in its own plug...
    user_agent = get_req_header(conn, "user-agent")
    conn = put_session(conn, :ua, user_agent)

    case conn.private[:plug_session_fetch] do
      :done ->
        case get_session(conn, :player_id) do
          nil ->
            player_id = Crossfire.Core.AlphaIdServer.new_player_id()

            conn
            |> put_session(:player_id, player_id)
            |> put_resp_cookie("player_id", player_id)

          _player_id ->
            conn
        end

      _ ->
        CU.lfi("Session not fetched yet")
        conn
    end
  end
end
