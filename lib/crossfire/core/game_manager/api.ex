defmodule Crossfire.Core.GameManager.Api do
  @moduledoc """
  Module providing an API and utility functions for starting and interacting with a game.
  """

  alias Crossfire.Core.Game
  alias Crossfire.Core.Types
  alias Crossfire.Core.GameManager.State, as: GMState
  alias Crossfire.Core.AlphaIdServer

  require Crossfire.Core.Util, as: CU

  @timeout 3000

  # TODO: add timeouts later where appropriate

  @spec game_server_id(Types.game_id()) :: Types.game_server_id()
  def game_server_id(game_id), do: :"GameServer_#{game_id}"

  def game_id(server_id) when is_binary(server_id) do
    String.split(server_id, "GameServer_") |> List.last()
  end

  def game_id(server_id) when is_atom(server_id) do
    game_id(Atom.to_string(server_id))
  end

  @spec new_game(Types.player_id(), [integer]) ::
          {:ok, GMState.t(), pid} | {:error, any}
  def new_game(owner_id, cps \\ []) do
    # Player has asked LobbyServer for a new game, and LobbyServer has called us.
    # We initialize a new GameState and start our server with that state and a
    #   server_id that we generate based on the game_id.
    # Anyone that knows a game_id can call us, getting the server_id from the game_id.

    game_id = AlphaIdServer.get_unique_id()

    players =
      if cps == [] do
        Game.build_players(owner_id)
      else
        Game.build_players_with_cps(owner_id, cps)
      end

    state = GMState.new(game_id, owner_id, players)

    case Crossfire.Core.GamesSupervisor.start_game(game_server_id(game_id), state) do
      {:ok, pid} ->
        Enum.each(players, fn {_player_num, player_id} ->
          if String.starts_with?(player_id, "CP-") do
            player_ready(game_id, player_id)
          end
        end)

        {:ok, state, pid}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def join_game(game_id, player_id) do
    GenServer.call(game_server_id(game_id), {:join_game, player_id})
  end

  def abandon_game(game_id, player_id) do
    try do
      GenServer.call(game_server_id(game_id), {:abandon_game, player_id})
    catch
      # Handle exits without raising an error, since there's nothing we can do about it anyway.
      :exit, {:normal, _} -> :ok
      :exit, reason -> {:error, reason}
    end
  end

  def get_game(game_id, timeout \\ @timeout) do
    # Normally we broadcast game updates, so this function may not be necessary
    #   except when player first joins game.
    safe_call(game_id, :get_game, timeout)
  end

  @doc """
  Fire a shot, effectively creating a new block in the game (if the player is allowed
  to shoot based on game rules).
  """
  def shoot(game_id, player_num, slot) do
    GenServer.cast(game_server_id(game_id), {:shoot, player_num, slot})
  end

  @doc """
  Mark a player as "ready".  This only makes sense for players already registered and
  occupying a player_num slot in the game.  Otherwise, it will return an error.
  """
  def player_ready(game_id, player_id) do
    GenServer.call(game_server_id(game_id), {:player_ready, player_id})
  end

  defp safe_call(game_id, message, timeout) do
    # Do a GenServer.call with timeout and error handling.  This probably should be a
    # more general function used in other modules as well.
    try do
      GenServer.call(game_server_id(game_id), message, timeout)
    catch
      :exit, {:noproc, _} -> {:error, :game_not_found}
      :exit, {:timeout, _} -> {:error, :timeout}
    end
  end

  @doc """
  Of all available player positions in the game, return the first one not occupied.
  """
  def first_open_player_slot(players) do
    Enum.filter(players, fn {_player_num, player_id} -> player_id in [nil, ""] end)
    |> Enum.map(fn {player_num, _} -> player_num end)
    |> Enum.min(fn -> 0 end)
  end

  @doc """
  Get the player_num (player position) for a game given a player_id.
  """
  @spec player_num(Types.players(), Types.player_id()) :: Types.player_num() | nil
  def player_num(players, player_id), do: CU.map_k_for_v(players, player_id, 0)

  @doc """
  Return a list of player positions which are not occupied.
  """
  @spec empty_player_slots(Types.players()) :: [Types.player_num()]
  def empty_player_slots(players) do
    players
    |> Map.keys()
    |> Enum.sort()
    |> Enum.filter(fn player_num -> Map.get(players, player_num, "") == "" end)
  end
end
