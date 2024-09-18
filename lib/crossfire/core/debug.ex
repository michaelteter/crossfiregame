defmodule Crossfire.Core.Debug do
  @moduledoc """
  Convenience functions for debugging in iex.

  Also note `should_log/1` which is used for controlling debug-related
  logging for various modules that use the Util.lfi() function.
  """

  alias Crossfire.Core.Lobby.Api, as: LobbyServer
  alias Crossfire.Core.GameManager.Api, as: GameServer
  alias Crossfire.Core.PubSub, as: Comm

  def my_messages do
    Process.info(self(), :messages)
  end

  def games do
    LobbyServer.list_games()
  end

  def lobby_server_state do
    :sys.get_state(:"Elixir.Crossfire.Core.Lobby.Server")
  end

  def game_server_state(game_id) do
    :sys.get_state(GameServer.game_server_id(game_id))
  end

  def should_log(module) do
    case module do
      # Crossfire.Core.Lobby.Server -> true
      # Crossfire.Core.GameManager.Server -> true
      # CrossfireWeb.GameLive.Index -> true
      # CrossfireWeb.LobbyLive.Index -> true
      # _ -> true
      _ -> false
    end
  end

  @doc """
  Send a message to redirect clients back to the lobby.
  """
  def back_to_lobby() do
    Comm.debug_control_back_to_lobby()
  end
end
