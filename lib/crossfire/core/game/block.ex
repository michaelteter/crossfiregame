defmodule Crossfire.Core.Game.Block do
  @moduledoc """
  Struct representing a "block" (or shot) in play.  This block may be on the board or
  staged one step outside the board, waiting until next game loop iteration to
  enter the board.
  """

  alias Crossfire.Core.Types
  alias Crossfire.Core.Const
  alias Crossfire.Core.Util, as: CU

  @derive {Jason.Encoder, only: [:pos, :player]}
  @type t :: %__MODULE__{
          pos: Types.board_pos(),
          player: Types.player_num()
        }

  # We will store the position as row*100+col as this simplifies JS interop and
  #   some other things.  It's also still humanly readable.
  defstruct(
    pos: 0,
    player: 0
  )

  @spec new_block(Types.player_num(), integer) :: t
  def new_block(player, slot) do
    # Player 1 is at the top of the board
    # Player 2 is at the bottom of the board
    # Player 3 is at the left of the board
    # Player 4 is at the right of the board

    # Blocks are initialized outside of the board, one step short of the position they would enter at.

    # Since we are now manging player-at-bottom perspective, we must change
    #   how slots are translated into blocks.

    # Actually, we do this reorientation in shoot(), so it is already correct at this point.
    position =
      case player do
        1 -> CU.to_position_key(Const.min_row() - 1, slot)
        2 -> CU.to_position_key(Const.max_row() + 1, slot)
        3 -> CU.to_position_key(slot, Const.min_col() - 1)
        4 -> CU.to_position_key(slot, Const.max_col() + 1)
      end

    %__MODULE__{pos: position, player: player}
  end

  @doc """
  Move a block one step in the direction away from its player.
  """
  @spec step(t) :: t
  def step(%__MODULE__{} = block) do
    {r, c} = CU.from_position_key(block.pos)

    new_pos =
      case block.player do
        1 -> {r + 1, c}
        2 -> {r - 1, c}
        3 -> {r, c + 1}
        4 -> {r, c - 1}
        _ -> :error
      end

    %__MODULE__{block | pos: CU.to_position_key(new_pos)}
  end
end
