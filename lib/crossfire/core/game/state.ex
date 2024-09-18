defmodule Crossfire.Core.Game.State do
  @moduledoc """
  This struct contains minimal information necessary to represent
  the state of a game.

  This includes the player scores, a map of player number to score count, and
  a list of active blocks.

  Other state that is relevant for managing a game in play is stored in the
  GameManager.State struct.
  """

  alias Crossfire.Core.Types
  alias Crossfire.Core.Game.Block

  @derive Jason.Encoder
  @type t :: %__MODULE__{
          scores: %{Types.player_num() => integer},
          active_blocks: [Block.t()]
        }

  defstruct(
    scores: %{},
    active_blocks: []
  )

  def new(player_count) do
    scores =
      1..player_count
      |> Enum.reduce(%{}, fn player_num, acc ->
        Map.put(acc, player_num, 0)
      end)

    %__MODULE__{scores: scores}
  end
end
