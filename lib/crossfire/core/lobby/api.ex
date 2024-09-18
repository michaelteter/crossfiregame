defmodule Crossfire.Core.Lobby.Api do
  @moduledoc """
  This module provides an API for the LobbyServer.
  """

  alias Crossfire.Core.Types
  alias Crossfire.Core.GameMetadata
  alias Crossfire.Core.GameManager.State, as: GMState

  # Comments
  # somenum is a way for us to associate related calls in the logs

  def servername, do: Crossfire.Core.Lobby.Server.servername()

  @spec list_games(Types.player_id() | nil) :: {:ok, list(GameMetadata.t())}
  def list_games(player_id \\ nil) do
    # Get a list of games, and sort with the player's game first if player_id provided
    GenServer.call(servername(), {:list_games, player_id})
  end

  def create_new_game(player_or_players, visibility, bot_count \\ 0) do
    GenServer.cast(servername(), {:create_new_game, player_or_players, visibility, bot_count})
  end

  def join_game(game_id, player_id) do
    GenServer.call(servername(), {:join_game, game_id, player_id})
  end

  def abandon_game(game_id, player_id) do
    GenServer.call(servername(), {:abandon_game, game_id, player_id})
  end

  def game_updated(%GMState{} = gmstate) do
    GenServer.cast(servername(), {:game_updated, gmstate})
  end

  def game_expired(game_id) do
    GenServer.cast(servername(), {:game_expired, game_id})
  end
end
