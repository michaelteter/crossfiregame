defmodule Crossfire.Core.Lobby.Server do
  @moduledoc """
  This module implements the LobbyServer.
  """

  use GenServer

  alias Crossfire.Core.Types
  alias Crossfire.Core.Const
  alias Crossfire.Core.GameMetadata
  alias Crossfire.Core.Lobby.State, as: LobbyState
  alias Crossfire.Core.GameManager.Api, as: GameServer
  alias Crossfire.Core.GameManager.State, as: GMState
  alias Crossfire.Core.PubSub, as: Comm

  require Crossfire.Core.Util, as: CU

  def servername, do: __MODULE__

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # ==============================================================================================================
  # GenServer Callbacks ==========================================================================================

  # Reminder: we'll handle request messages from the client, doing whatever is necessary,
  #   returning success/failure.
  # Whatever was done in the process may result in bcasts to the games list
  #   and/or to a specific game.
  # I _think_ we will never reply with an updated game to the client...

  @impl true
  def init(_opts) do
    {:ok, LobbyState.new()}
  end

  @impl true
  def handle_call(msg, _from, %LobbyState{} = state) do
    {response, state} =
      case msg do
        {:list_games, player_id} ->
          call_list_games(player_id, state)

        _ ->
          CU.lfi("handle_call: Unknown message: #{CU.inspect_msg(msg)}")
          {:error, state}
      end

    {:reply, response, state}
  end

  @impl true
  def handle_cast(msg, %LobbyState{} = state) do
    state =
      case msg do
        {:create_new_game, owner_id, visibility, bot_count} ->
          cast_create_new_game(owner_id, visibility, bot_count, state)

        {:game_updated, gmstate} ->
          cast_game_updated(gmstate, state)

        {:game_expired, game_id} ->
          cast_game_expired(game_id, state)

        _ ->
          CU.lfi("handle_cast: Unknown message: #{CU.inspect_msg(msg)}")
          state
      end

    {:noreply, state}
  end

  # ==============================================================================================================
  # Cast Handlers ================================================================================================

  def cast_game_expired(game_id, state) do
    CU.lfi("cast_game_expired: game_id: #{game_id}")
    state = %{state | games: Map.delete(state.games, game_id)}
    Comm.bcast_to_games_list({:game_expired, game_id}, "LobbyServer :game_expired")
    state
  end

  @spec cast_game_updated(GMState.t(), LobbyState.t()) :: LobbyState.t()
  def cast_game_updated(%GMState{} = gmstate, %LobbyState{} = state) do
    m = update_game_metadata(Map.get(state.games, gmstate.id), gmstate)

    case m.visibility do
      :public ->
        Comm.bcast_game_metadata_to_games_list_topic(m, "LobbyServer :game_updated")

      :private ->
        Comm.bcast_to_game_topic(gmstate.id, {:gmstate_updated, gmstate})
    end

    LobbyState.set_game(state, m)
  end

  @spec cast_create_new_game(
          Types.player_id(),
          Types.game_visibility(),
          integer(),
          LobbyState.t()
        ) ::
          LobbyState.t()
  def cast_create_new_game(owner_id, visibility, bot_count, %LobbyState{} = state) do
    # TODO: do this right using Enum and max_player_count
    bot_positions =
      case bot_count do
        0 -> []
        1 -> [4]
        2 -> [3, 4]
        3 -> [2, 3, 4]
      end

    CU.lfi("+cast_create_new_game+ bot_positions = #{inspect(bot_positions)}")

    case GameServer.new_game(owner_id, bot_positions) do
      {:ok, gmstate, _gmpid} ->
        m = new_game_metadata(gmstate, visibility)
        CU.lfi("+cast_create_new_game+ m = #{inspect(m)}")

        # I know these two bcasts are inconsisten wrt arguments :(
        if visibility == :public do
          Comm.bcast_to_games_list(:new_game_exists, m)
        else
          Comm.bcast_to_player(owner_id, {:new_game_exists, m})
        end

        LobbyState.set_game(state, m)
    end
  end

  # ==============================================================================================================
  # Call Handlers ================================================================================================

  @spec call_list_games(Types.player_id(), LobbyState.t()) :: {any, LobbyState.t()}
  def call_list_games(player_id, %LobbyState{} = state) do
    games = LobbyState.get_player_and_public_games(state, player_id)
    {{:ok, games}, state}
  end

  # # ==============================================================================================================
  # # Core Functions ===============================================================================================

  def new_game_metadata(%GMState{} = gmstate, visibility) do
    %GameMetadata{
      id: gmstate.id,
      owner_id: gmstate.owner_id,
      visibility: visibility,
      status: gmstate.status,
      players: gmstate.players,
      player_count: player_count(gmstate.players),
      players_ready: MapSet.new(),
      player_role: :none
    }
  end

  @spec update_game_metadata(GameMetadata.t(), GMState.t()) :: GameMetadata.t()
  def update_game_metadata(%GameMetadata{} = m, %GMState{} = gmstate) do
    %GameMetadata{
      m
      | players: gmstate.players,
        player_count: player_count(gmstate.players),
        status: gmstate.status
    }
  end

  @spec player_count(Types.players()) :: integer
  defp player_count(players) do
    Const.num_players() - Enum.count(GameServer.empty_player_slots(players))
  end
end
