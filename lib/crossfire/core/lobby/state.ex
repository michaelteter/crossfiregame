defmodule Crossfire.Core.Lobby.State do
  @moduledoc """
  This module defines the state of the LobbyServer.

  It's just a map of game_id to GameMetadata.
  """

  alias Crossfire.Core.Types
  alias Crossfire.Core.GameMetadata

  require Crossfire.Core.Util, as: CU

  @type t :: %__MODULE__{
          games: %{Types.game_id() => GameMetadata.t()}
        }

  defstruct(games: %{})

  ###################################################################################

  @spec new() :: t
  def new, do: %__MODULE__{games: %{}}

  def set_game(%__MODULE__{} = state, %GameMetadata{} = m) do
    CU.lfi("=set_game= state: #{inspect(state)}")
    CU.lfi("=set_game= m: #{inspect(m)}")
    %{state | games: Map.put(state.games, m.id, m)}
  end

  @spec get_game(t, Types.game_id()) :: GameMetadata.t() | nil
  def get_game(%__MODULE__{} = state, game_id) do
    Map.get(state.games, game_id)
  end

  @spec get_games_by_owner(t, Types.player_id()) :: list(GameMetadata.t())
  def get_games_by_owner(%__MODULE__{} = state, owner_id) do
    state.games
    |> Enum.filter(fn {_, m} -> m.owner_id == owner_id end)
    |> Enum.map(fn {_, m} -> m end)
  end

  @doc """
  Get a list of games.

  These games will be ordered by:
  1. Games owned by the player
  2. Games the player is in
  3. Other public games
  """
  @spec get_player_and_public_games(t, Types.player_id()) :: list(GameMetadata.t())
  def get_player_and_public_games(%__MODULE__{} = state, player_id) do
    state.games
    |> Enum.reduce([], fn {_, m}, acc ->
      cond do
        m.owner_id == player_id ->
          [Map.put(m, :player_role, :owner) | acc]

        Enum.any?(m.players, fn {_, v} -> v == player_id end) ->
          [Map.put(m, :player_role, :player) | acc]

        m.visibility == :public ->
          [Map.put(m, :player_role, :none) | acc]

        true ->
          acc
      end
    end)
    # This really could have gone in Lobby.Handlers.list_games...
    |> Enum.sort_by(&role_priority/1)
  end

  defp role_priority(%{player_role: :owner}), do: 0
  defp role_priority(%{player_role: :player}), do: 1
  defp role_priority(%{player_role: :none}), do: 2
end
