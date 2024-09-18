defmodule Crossfire.Core.GameManager.Server do
  @moduledoc """
  This module is the GenServer that manages the game state for a single game.
  """

  use GenServer

  alias Crossfire.Core.Const
  alias Crossfire.Core.Types
  alias Crossfire.Core.Game
  alias Crossfire.Core.GameManager.Api, as: GameServer
  alias Crossfire.Core.GameManager.State, as: GMState
  alias Crossfire.Core.Lobby.Api, as: LobbyServer
  alias Crossfire.Core.PubSub, as: Comm

  require Crossfire.Core.Util, as: CU

  def start_server(game_server_id, state) do
    GenServer.start_link(__MODULE__, state, name: game_server_id)
  end

  # ==============================================================================================================
  # Return Helpers (ensure we return the correct type/shape) =====================================================

  # One of my biggest challenges was ensuring that I returned the correct response for
  #   different situations.  Often I would return something of the wrong shape and
  #   inadvertently corrupt my state.  These functions are an attempt to wrap returns
  #   and make their purpose more clear.
  # I'm not sure if this is a good practice, and really I feel like there must be a better
  #   way of handling all this in the context of GenServers and Process messages etc.
  # It feels a bit like spaghetti and gotos from ages past.

  def return_from_init(%GMState{} = state), do: {:ok, state}

  def return_from_cast(%GMState{} = state), do: {:noreply, state}

  def return_from_call(reply, %GMState{} = state), do: {:reply, reply, state}

  def return_from_info(%GMState{} = state), do: {:noreply, state}

  def return_from_continue(%GMState{} = state), do: {:noreply, state}

  # ==============================================================================================================
  # GenServer Callbacks ==========================================================================================

  @impl true
  def init(initial_state), do: return_from_init(initial_state)

  @impl true
  def handle_info({:game_expiration, _sn, _}, %GMState{} = state) do
    # sn would be used if we were logging, as it can help humans associate together
    #   src/dest or related messages in the log
    terminate_game(state)

    # NOTE: this function must exist separately from the following implementation
    #   of handle_info because the return structure of this function is different.
    #   This function returns a :stop tuple, while the other returns a :noreply tuple.
  end

  @impl true
  def handle_info(msg, %GMState{} = state) do
    CU.lfi("=handle_info= msg: #{CU.inspect_msg(msg)}")

    state =
      if msg == state.timer do
        case msg do
          {:countdown_tick, _, _} -> info_countdown_tick(state)
          {:game_loop_tick, _, _} -> info_game_loop_tick(state)
          _ -> info_unexpected_timer_msg(state, msg)
        end
      else
        case msg do
          # Maybe more msgs handled later
          _ -> info_unknown_msg(state, msg)
        end
      end

    return_from_info(state)
  end

  @impl true
  def handle_call({:abandon_game, player_id}, _from, state) do
    # NOTE: this function is separate from the other handle_call because it
    #   may return a :stop tuple instead of the usual {:reply, ...} tuple.
    # Managing return structures is quite a challenge...
    call_abandon_game(player_id, state)
  end

  @impl true
  def handle_call(msg, _from, state) do
    {result, %GMState{} = state} =
      case msg do
        :get_game -> {{:ok, state}, state}
        {:join_game, player_id} -> call_join_game(player_id, state)
        {:player_ready, player_id} -> call_player_ready(player_id, state)
        _ -> call_unknown_msg(msg, state)
      end

    return_from_call(result, state)
  end

  @impl true
  def handle_cast(msg, state) do
    CU.lfi("=handle_cast= msg: #{CU.inspect_msg(msg)}\n    state: #{inspect(state)}")

    {_result, state} =
      case msg do
        {:shoot, player_num, slot} -> cast_shoot(player_num, slot, state)
        _ -> cast_unknown_msg(msg, state)
      end

    return_from_cast(state)
  end

  # ==============================================================================================================
  # Info (msg) Handlers ==========================================================================================

  @spec info_countdown_tick(GMState.t()) :: GMState.t()
  def info_countdown_tick(%GMState{} = state) do
    {_timer_event, sn, ticks_remaining} = state.timer
    CU.lfi("=info_countdown_tick= sn: #{sn} // state: #{inspect(state)}")

    case ticks_remaining do
      0 -> start_playing(state)
      _ -> countdown_tick(state)
    end
  end

  @spec info_game_loop_tick(GMState.t()) :: GMState.t()
  def info_game_loop_tick(%GMState{} = state) do
    if state.status == :playing do
      game_loop_tick(state)
    else
      # This shouldn't happen.  We don't know what status to set...
      cancel_timer(state)
    end
  end

  @spec info_unexpected_timer_msg(GMState.t(), any) :: GMState.t()
  def info_unexpected_timer_msg(%GMState{} = state, msg) do
    CU.lfi("info_unexpected_timer_msg: Unexpected timer msg: #{CU.inspect_msg(msg)}")
    state
  end

  @spec info_unknown_msg(GMState.t(), any) :: GMState.t()
  def info_unknown_msg(%GMState{} = state, msg) do
    CU.lfi("info_unknown_msg: Unknown msg: #{CU.inspect_msg(msg)}")
    state
  end

  # ==============================================================================================================
  # Cast Handlers ================================================================================================

  def cast_shoot(player_num, slot, %GMState{} = state) do
    {_result, game} = Game.shoot(state.game, player_num, slot)
    state = %{state | game: game}
    holding_shots = Game.holding_shots(game)
    Comm.bcast_to_game_topic(state.id, {:holding_shots_updated, holding_shots})
    {:ok, state}
  end

  @spec cast_unknown_msg(any, GMState.t()) :: {:error, GMState.t()}
  def cast_unknown_msg(msg, %GMState{} = state) do
    CU.lfi("cast_unknown_msg: Unknown msg: #{CU.inspect_msg(msg)}")
    {:error, state}
  end

  # ==============================================================================================================
  # Call Handlers ================================================================================================

  @spec call_abandon_game(Types.player_id(), GMState.t()) ::
          {atom, GMState.t()} | {:stop, :normal, GMState.t()}
  def call_abandon_game(player_id, %GMState{} = state) do
    player_num = GameServer.player_num(state.players, player_id)

    complex_result =
      case abandon_game(player_num, state) do
        {:not_a_player, state} ->
          # IO.inspect("call_abandon_game :not_a_player")
          {:reply, :not_a_player, state}

        {:stop, :normal, state} ->
          # IO.inspect("call_abandon_game :stop, :normal, state")
          # {:reply, :stop, :normal, state} apparently this is wrong
          {:stop, :normal, state}

        # {:ok, state}
        {:ok, %GMState{} = state} ->
          # IO.inspect("call_abandon_game :ok, state")
          {:reply, :ok, state}
      end

    complex_result
  end

  @spec call_join_game(Types.player_id(), GMState.t()) :: {atom, GMState.t()}
  def call_join_game(player_id, %GMState{} = state) do
    case add_player(state, player_id) do
      :game_full ->
        {:game_full, state}

      :player_already_in_game ->
        {:ok, state}

      %GMState{} = state ->
        # tell lobby server that there is updated game data
        LobbyServer.game_updated(state)
        {:ok, state}
    end
  end

  @spec call_player_ready(Types.player_id(), GMState.t()) :: {atom, GMState.t()}
  def call_player_ready(player_id, %GMState{} = state) do
    # If game is already in game loop, ignore this.
    if state.status != :waiting_for_players do
      {:ok, state}
    else
      # Ensure player is in our list of players (rather than an observer who wandered here).
      CU.lfi("=handle_call= :player_ready, player_id: #{player_id}")
      CU.lfi("state: #{inspect(state)}")

      # Explicitly received the result here and send our return "value" at the
      #   bottom of this function (so we avoid mistakes in return values).
      # Remember that on call handlers the final return is
      #   {:reply, some_message, genserver_state}.
      #   Currently our generic call handler/dispatcher is adding the :reply,
      #   and we just return the some_message and state)
      {result, %GMState{} = state} =
        case GameServer.player_num(state.players, player_id) do
          0 -> {:not_a_player, state}
          player_num -> player_ready(player_num, state)
        end

      {result, %GMState{} = state}
    end
  end

  @spec call_unknown_msg(any, GMState.t()) :: {:error, GMState.t()}
  def call_unknown_msg(msg, %GMState{} = state) do
    CU.lfi("call_unknown_msg: Unknown msg: #{CU.inspect_msg(msg)}")
    {:error, state}
  end

  # ==============================================================================================================
  # Helpers ======================================================================================================

  @spec add_player(GMState.t(), Types.player_id()) :: atom | GMState.t()
  defp add_player(%GMState{} = gmstate, player_id) do
    players = gmstate.players

    # Don't add player more than once if player is already in the game.
    if GameServer.player_num(players, player_id) == 0 do
      case GameServer.first_open_player_slot(players) do
        nil -> :game_full
        player_num -> %{gmstate | players: Map.put(players, player_num, player_id)}
      end
    else
      :player_already_in_game
    end
  end

  @spec set_timer(GMState.t(), Types.timer_type(), integer) :: GMState.t()
  defp set_timer(%GMState{} = state, timer_type, ticks_remaining) do
    # sn is a way for us to associate related events in the logs.
    sn = CU.somenum()

    {timer, timer_ref} =
      case timer_type do
        :countdown ->
          msg = {:countdown_tick, sn, ticks_remaining}
          ref = Process.send_after(self(), msg, Const.sec_in_ms())
          {msg, ref}

        :game_loop ->
          msg = {:game_loop_tick, sn, ticks_remaining}
          ref = Process.send_after(self(), msg, Const.game_loop_tick_interval())
          {msg, ref}

        :expiration ->
          msg = {:game_expiration, sn, ticks_remaining}
          ref = Process.send_after(self(), msg, Const.game_expiration_secs() * Const.sec_in_ms())
          {msg, ref}

        nil ->
          if !is_nil(state.timer_ref), do: Process.cancel_timer(state.timer_ref)

          {nil, nil}
      end

    %{state | timer: timer, timer_ref: timer_ref}
  end

  @spec cancel_timer(GMState.t()) :: GMState.t()
  defp cancel_timer(%GMState{} = state), do: set_timer(state, nil, 0)

  defp player_ready(player_num, %GMState{} = state) do
    # We need to just tell LobbyServer about the updated game.
    # It can update its state of metadatas and also inform the players.

    players_ready = MapSet.put(state.players_ready, player_num)
    state = %{state | players_ready: players_ready}

    state =
      if MapSet.size(players_ready) == Const.num_players() do
        %{set_timer(state, :countdown, Const.countdown_secs()) | status: :countdown}
      else
        state
      end

    # Update LobbyServer, and it can broadcast if necessary (public/private)
    LobbyServer.game_updated(state)

    # Update our GameLive users
    Comm.bcast_to_game_topic(state.id, {:player_ready, player_num, state})
    {:ok, state}
  end

  @spec abandon_game(Types.player_num(), GMState.t()) ::
          {:not_a_player, GMState.t()} | {:ok, GMState.t()}
  defp abandon_game(0, %GMState{} = state), do: {:not_a_player, state}

  @spec abandon_game(Types.player_num(), GMState.t()) ::
          {:ok, GMState.t()} | {:stop, :normal, GMState.t()}
  defp abandon_game(player_num, %GMState{} = state) do
    CU.lfi("=abandon_game= player_num: #{player_num} // state: #{inspect(state)}")

    # Remove player from game
    state = %{
      state
      | players: Map.put(state.players, player_num, ""),
        players_ready: MapSet.delete(state.players_ready, player_num)
    }

    if Enum.count(state.players, fn {_, v} -> v != "" end) == 0 do
      # No players left in game.  End the game.
      terminate_game(state)
      # returns {:stop, :normal, state}
    else
      state =
        case state.status do
          :waiting_for_players ->
            # Still waiting for players.  Notify Lobby of updated game state.
            state

          :countdown ->
            state = cancel_timer(state)
            %{state | status: :waiting_for_players}

          :playing ->
            # If game is in game loop, stop the game loop
            state = cancel_timer(state)
            # Add an expiration timer since the game is effectively dead now.
            state = set_timer(state, :expiration, Const.game_expiration_secs())
            %{state | status: :ended}
        end

      LobbyServer.game_updated(state)
      # Update our GameLive users
      Comm.bcast_to_game_topic(state.id, {:player_left, player_num, state})
      {:ok, %GMState{} = state}
    end
  end

  @spec start_playing(GMState.t()) :: GMState.t()
  defp start_playing(%GMState{} = state) do
    state = %{set_timer(state, :game_loop, 9999) | status: :playing}

    LobbyServer.game_updated(state)
    Comm.bcast_to_game_topic(state.id, {:gmstate_updated, state})
    state
  end

  @spec countdown_tick(GMState.t()) :: GMState.t()
  defp countdown_tick(%GMState{} = state) do
    {_timer_event, sn, ticks_remaining} = state.timer
    CU.lfi("=perform_countdown_tick= sn: #{sn} // state: #{inspect(state)}")
    # CU.lfi("state: #{inspect(state)}")

    ticks_remaining = ticks_remaining - 1
    state = %{set_timer(state, :countdown, ticks_remaining) | status: :countdown}
    Comm.bcast_to_game_topic(state.id, {:countdown_tick, ticks_remaining})
    state
  end

  @spec end_game(GMState.t()) :: GMState.t()
  defp end_game(%GMState{} = state) do
    %GMState{} = state = %{cancel_timer(state) | status: :ended}
    %GMState{} = state = set_timer(state, :expiration, 0)
    Comm.bcast_to_game_topic(state.id, {:game_ended, state})
    %GMState{} = state
  end

  defp game_loop_tick(%GMState{} = state) do
    case Game.tick(state.game) do
      {:game_over, game} ->
        end_game(%{state | game: game})

      {:ok, game} ->
        {_timer_event, _sn, ticks_remaining} = state.timer
        state = %{state | game: game}
        Comm.bcast_to_game_topic(state.id, {:game_loop_tick, state})
        bot_actions(state)
        set_timer(state, :game_loop, ticks_remaining - 1)
    end
  end

  defp terminate_game(%GMState{} = state) do
    CU.lfi("=terminate_game= state: #{inspect(state)}")
    state = cancel_timer(state)
    LobbyServer.game_expired(state.id)
    Comm.bcast_to_game_topic(state.id, :game_expired)
    {:stop, :normal, state}
  end

  defp bot_actions(%GMState{} = state) do
    Enum.each(state.players, fn {player_num, player_id} ->
      if String.starts_with?(player_id, "CP-") do
        # Brute force attempt to fire N random shots.
        # There may already be shots in play, so some of these firing attempts
        #   may be ignored.  But then, human players may be wildly mashing keys
        #   too, so it's probably more realistic :)
        slots =
          1..8
          |> Enum.to_list()
          |> Enum.shuffle()
          |> Enum.take(:rand.uniform(Const.max_active_shots_per_player()))

        Enum.each(slots, fn slot ->
          Crossfire.Core.GameManager.Api.shoot(state.id, player_num, slot)
        end)
      end
    end)
  end
end
