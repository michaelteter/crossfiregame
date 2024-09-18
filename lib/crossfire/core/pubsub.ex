defmodule Crossfire.Core.PubSub do
  @moduledoc """
  This module provides a PubSub API for the Crossfire application.

  Some of these convenience functions may be unused.  This module is in need
  of a review and cleanup.
  """

  alias Crossfire.Core.GameMetadata
  alias Crossfire.Core.Game.State, as: GameState

  require Crossfire.Core.Util, as: CU

  @debug_control_topic "debug:control"

  # NOTE: We tend to send GameMetadata to games_list,
  #   and GameState to game topics.
  #   This means that if we need to send a private game update to a LobbyLive client, we should
  #   send a custom message to the game topic, and not to the games_list topic.

  # ------------------------------------------------------------------------------------------------
  # -- General -------------------------------------------------------------------------------------

  def debug_control_back_to_lobby() do
    bcast(@debug_control_topic, :debug_control_back_to_lobby)
  end

  def bcast(topic, msg), do: Phoenix.PubSub.broadcast(Crossfire.PubSub, topic, msg)

  def bcast(topic, msg, caller_info) do
    CU.lfi("=bcast= topic: #{topic}, caller: #{inspect(caller_info)}")
    Phoenix.PubSub.broadcast(Crossfire.PubSub, topic, msg)
  end

  # ------------------------------------------------------------------------------------------------
  # -- Player Topic --------------------------------------------------------------------------------

  def player_topic(player_id), do: "player:#{player_id}:updates"

  def sub_to_player(player_id) do
    Phoenix.PubSub.subscribe(Crossfire.PubSub, player_topic(player_id))
  end

  def unsub_from_player(player_id) do
    Phoenix.PubSub.unsubscribe(Crossfire.PubSub, player_topic(player_id))
  end

  def bcast_to_player(player_id, msg, caller_info \\ nil) do
    if is_binary(caller_info) do
      CU.lfi("=bcast_to_player= player_id: #{player_id}, caller: #{inspect(caller_info)}")
    end

    bcast(player_topic(player_id), msg, caller_info)
  end

  # ------------------------------------------------------------------------------------------------
  # -- Games List ----------------------------------------------------------------------------------

  def public_games_list_topic, do: "public_games:updates"

  def sub_to_games_list do
    Phoenix.PubSub.subscribe(Crossfire.PubSub, public_games_list_topic())
  end

  def unsub_from_games_list do
    Phoenix.PubSub.unsubscribe(Crossfire.PubSub, public_games_list_topic())
  end

  def bcast_game_metadata_to_games_list_topic(%GameMetadata{} = m, _caller_info \\ nil) do
    bcast(public_games_list_topic(), game_metadata_updated_msg(m))
  end

  def bcast_to_games_list(msg, data, caller_info \\ nil) do
    if is_binary(caller_info), do: CU.lfi("=bcast_to_games_list= caller: #{inspect(caller_info)}")
    bcast(public_games_list_topic(), {msg, data}, caller_info)
  end

  # ------------------------------------------------------------------------------------------------
  # -- Game ----------------------------------------------------------------------------------------

  def sub_to_debug_control() do
    Phoenix.PubSub.subscribe(Crossfire.PubSub, @debug_control_topic)
  end

  def unsub_from_debug_control() do
    Phoenix.PubSub.unsubscribe(Crossfire.PubSub, @debug_control_topic)
  end

  # TODO: fix these... currently only bcast_to_game_topic is used.

  def game_topic(game_id), do: "game:#{game_id}:updates"

  def sub_to_game(game_id) do
    Phoenix.PubSub.subscribe(Crossfire.PubSub, game_topic(game_id))
  end

  def unsub_from_game(game_id) do
    Phoenix.PubSub.unsubscribe(Crossfire.PubSub, game_topic(game_id))
  end

  def bcast_game_metadata_to_game_topic(%GameMetadata{} = m, caller_info \\ nil) do
    bcast(game_topic(m.id), game_metadata_updated_msg(m), caller_info)
  end

  def bcast_to_game_topic(game_id, msg, caller_info \\ nil) do
    # Caller can send whatever they want as msg, but two common uses are:
    #  game_updated_msg(game) and game_metadata_updated_msg(metadata)
    if is_binary(caller_info),
      do: IO.inspect("=bcast_to_game= game_id: #{game_id}, caller: #{inspect(caller_info)}")

    bcast(game_topic(game_id), msg, caller_info)
  end

  # ------------------------------------------------------------------------------------------------
  # -- Internal ------------------------------------------------------------------------------------

  def game_updated_msg(%GameState{} = game), do: {:game_updated, game}

  def game_metadata_updated_msg(%GameMetadata{} = m), do: {:game_metadata_updated, m}
end
