defmodule Crossfire.Core.GameManager.State do
  @moduledoc """
  This module defines the state of a managed game.

  It is comprised of metadata such as the game owner, the players, the current
  timer if appropriate, and the game state itself.
  """

  alias Crossfire.Core.Types
  alias Crossfire.Core.Const
  alias Crossfire.Core.Game.State, as: GameState

  @type t :: %__MODULE__{
          id: Types.game_id(),
          owner_id: Types.player_id(),
          players: Types.players(),
          players_ready: MapSet.t(),
          game: GameState.t(),
          status: Types.game_status(),
          timer: nil | {Types.timer_type(), integer, integer},
          timer_ref: nil | reference()
        }

  defstruct(
    id: "",
    owner_id: "",
    players: %{},
    players_ready: MapSet.new(),
    game: %GameState{},
    status: :waiting_for_players,
    timer: nil,
    timer_ref: nil
  )

  @spec new(Types.game_id(), Types.player_id(), Types.players()) :: t
  def new(game_id, owner_id, players) do
    %__MODULE__{
      id: game_id,
      owner_id: owner_id,
      players: players,
      players_ready: MapSet.new(),
      game: GameState.new(Const.num_players()),
      status: :waiting_for_players,
      timer: nil,
      timer_ref: nil
    }
  end
end
