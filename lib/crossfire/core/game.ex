defmodule Crossfire.Core.Game do
  @moduledoc """
  This module provides the game logic.
  """

  alias Crossfire.Core.Types
  alias Crossfire.Core.Const
  alias Crossfire.Core.Game.Block
  alias Crossfire.Core.Game.State, as: GameState
  alias Crossfire.Core.Util, as: CU

  require Crossfire.Core.Util, as: CU

  @spec new :: GameState.t()
  def new, do: GameState.new(Const.num_players())

  @doc """
  Returns the number of shots available for a player.  This is the
  difference between the maximum allowed active shots and the number of
  currently active shots for the player.
  """
  @spec shots_available(GameState.t(), Types.player_num()) :: integer
  def shots_available(%GameState{} = game, player) do
    Const.max_active_shots_per_player() - active_block_count(game, player)
  end

  @doc """
  Returns a map of player_num -> shots_available for all players.
  """
  @spec shots_available(GameState.t()) :: %{Types.player_num() => integer}
  def shots_available(%GameState{} = game) do
    Enum.reduce(1..Const.num_players(), %{}, fn player, acc ->
      Map.put(acc, player, shots_available(game, player))
    end)
  end

  @doc """
  This function returns a MapSet of all shots that are held - i.e. shots that
  are staged to be placed on the board on the next game loop tick.

  Each held shot is expressed as a tuple of {player_num, slot}.

  Slot number is based on the internal player position, and then starting from
  left to right or top to bottom.

  Shots are determined to be "held" if they lay one step outside the board.
  """
  @spec holding_shots(GameState.t()) :: MapSet.t({Types.player_num(), integer})
  def holding_shots(%GameState{} = game) do
    Enum.reduce(game.active_blocks, MapSet.new(), fn %Block{pos: pos, player: player}, acc ->
      {r, c} = CU.from_position_key(pos)

      cond do
        player == 1 && r == Const.min_row() - 1 -> MapSet.put(acc, {player, c})
        player == 2 && r == Const.max_row() + 1 -> MapSet.put(acc, {player, c})
        player == 3 && c == Const.min_col() - 1 -> MapSet.put(acc, {player, r})
        player == 4 && c == Const.max_col() + 1 -> MapSet.put(acc, {player, r})
        true -> acc
      end
    end)
  end

  @doc """
  Build an empty players structure: {player_num => player_id}.

  Empty player positions are represented by an empty string.  Possibly in other
  places it is nil.  This should be reviewed and standardized, but that's a future
  task.
  """
  @spec build_players() :: Types.players()
  def build_players do
    # Build a map of player_num -> "" for Const.num_players() players
    Enum.reduce(1..Const.num_players(), %{}, fn player_num, acc ->
      Map.put(acc, player_num, "")
    end)
  end

  @spec build_players(Types.player_id()) :: Types.players()
  def build_players(player_id) when is_binary(player_id) do
    build_players([player_id])
  end

  @spec build_players([Types.player_id()]) :: Types.players()
  def build_players(player_ids) when is_list(player_ids) do
    players = build_players()

    Enum.reduce(Enum.with_index(player_ids, 1), players, fn {player_id, player_pos}, acc ->
      Map.put(acc, player_pos, player_id)
    end)
  end

  @doc """
  Build a players structure with the given player as the owner and the
  provided list of player positions filled with computer players.
  """
  @spec build_players_with_cps(Types.player_id(), [Types.player_num()]) :: Types.players()
  def build_players_with_cps(owner_id, cps) do
    # Initialize the result list with owner_id in the first position
    initial_list = [owner_id, "", "", ""]

    Enum.reduce(cps, initial_list, fn cp_num, acc ->
      # Replace the empty string at the index corresponding to the player number
      List.replace_at(acc, cp_num - 1, "CP-#{cp_num}")
    end)
    |> build_players()
  end

  @doc """
  Return a list of player_ids other than the provided player_id.
  """
  @spec other_players(Types.players(), Types.player_id()) :: [Types.player_id()]
  def other_players(players, player_id) do
    Enum.filter(Map.values(players), fn p_id -> p_id not in [player_id, "", nil] end)
  end

  @spec active_block_count(GameState.t(), Types.player_num()) :: integer
  def active_block_count(%GameState{} = game, player) do
    Enum.count(game.active_blocks, fn block -> block.player == player end)
  end

  @spec held_shot?(GameState.t(), Types.player_num(), Types.slot()) :: boolean()
  defp held_shot?(%GameState{} = game, player, slot) do
    MapSet.member?(holding_shots(game), {player, slot})
  end

  defp reorient_slot(player, slot) do
    # Players are presented an orientation that differs from the actual internally
    #   stored game.  For example, player 1 hits the 1 key to fire in what they
    #   think is slot 1, but the player position is actually at the top.
    #   So the situation is rotated 180 degrees from how it appears.
    #   Thus, player 1 slot 1 is actually player 1 slot 8.
    # Rotations apply for players 1, 3, and 4.  Player 2 is naturally at the bottom.
    case player do
      1 -> Const.max_col() - slot + 1
      2 -> slot
      3 -> slot
      4 -> Const.max_row() - slot + 1
    end
  end

  @spec shoot(GameState.t(), Types.player_num(), Types.slot()) :: {atom, GameState.t()}
  def shoot(%GameState{} = game, player, slot) do
    player = if is_binary(player), do: String.to_integer(player), else: player
    slot = if is_binary(slot), do: String.to_integer(slot), else: slot

    real_slot = reorient_slot(player, slot)

    cond do
      active_block_count(game, player) >= Const.max_active_shots_per_player() ->
        {:no_shots_free, game}

      held_shot?(game, player, real_slot) ->
        {:shot_already_holding, game}

      true ->
        game = %GameState{
          game
          | active_blocks: game.active_blocks ++ [Block.new_block(player, real_slot)]
        }

        {:ok, game}
    end
  end

  @spec handle_boundary(GameState.t(), Block.t()) :: GameState.t()
  def handle_boundary(%GameState{} = game, %Block{} = moved_block) do
    # Called when boundary reached; update score and remove block
    scores = Map.update!(game.scores, moved_block.player, &(&1 + 1))
    active_blocks = Enum.reject(game.active_blocks, &(&1 == moved_block))

    %GameState{game | scores: scores, active_blocks: active_blocks}
  end

  @spec check_boundaries(GameState.t()) :: GameState.t()
  def check_boundaries(%GameState{} = game) do
    Enum.reduce(game.active_blocks, game, fn block, game_acc ->
      if reached_boundary?(Block.step(block)),
        do: handle_boundary(game_acc, block),
        else: game_acc
    end)
  end

  @spec move_blocks([Block.t()]) :: [Block.t()]
  def move_blocks(active_blocks) do
    Enum.reduce(active_blocks, [], fn block, acc -> [Block.step(block) | acc] end)
  end

  @spec check_collisions([Block.t()]) :: {[Block.t()], [Block.t()]}
  def check_collisions(moved_blocks) do
    position_grouped_blocks = Enum.group_by(moved_blocks, fn block -> block.pos end)

    collision_blocks =
      position_grouped_blocks
      |> Enum.filter(fn {_pos, blocks} -> length(blocks) > 1 end)
      |> Enum.flat_map(fn {_pos, blocks} -> blocks end)

    final_blocks =
      position_grouped_blocks
      |> Enum.filter(fn {_pos, blocks} -> length(blocks) == 1 end)
      |> Enum.flat_map(fn {_pos, blocks} -> blocks end)

    {collision_blocks, final_blocks}
  end

  @spec opposite_player(Types.player_num()) :: Types.player_num()
  def opposite_player(player) do
    case player do
      1 -> 2
      2 -> 1
      3 -> 4
      4 -> 3
    end
  end

  @spec prev_pos(Types.board_pos(), Types.player_num()) :: Types.board_pos()
  def prev_pos(pos, player) do
    {r, c} = CU.from_position_key(pos)

    {new_r, new_c} =
      case player do
        1 -> {r - 1, c}
        2 -> {r + 1, c}
        3 -> {r, c - 1}
        4 -> {r, c + 1}
      end

    CU.to_position_key(new_r, new_c)
  end

  def cross_path_collision_check([], final_blocks), do: final_blocks

  @doc """
  This function will check for collisions where two opposing players'
  blocks would pass through each other rather than land on the same spot.

  This will count as a collision also.
  """
  @spec cross_path_collision_check([Block.t()], [Block.t()]) :: [Block.t()]
  def cross_path_collision_check([block | rest], final_blocks) do
    check_block = %Block{
      pos: prev_pos(block.pos, block.player),
      player: opposite_player(block.player)
    }

    case Enum.find(rest, fn b -> b == check_block end) do
      nil ->
        cross_path_collision_check(rest, [block | final_blocks])

      _ ->
        # Ensure check_block and block do not end up in final_blocks.
        # Current block is "removed" by not being added to final_blocks.
        # Check block is removed by not being passed to the next iteration.
        updated_rest = Enum.reject(rest, fn b -> b == check_block end)
        cross_path_collision_check(updated_rest, final_blocks)
    end
  end

  def hacky_collision_check(moved_blocks) do
    # For each block, check if there's a block "behind" it belonging to its opposite player.
    # If there is, remove both blocks.
    cross_path_collision_check(moved_blocks, [])
  end

  @spec tick(GameState.t()) :: {:game_over, GameState.t()} | {:ok, GameState.t()}
  def tick(%GameState{} = game) do
    # 1. Check and remove all blocks that would reach the boundary.
    # 2. Move all blocks to their next position.
    # 3. Check for collisions.
    # 4. Check for end of game (winning condition).

    game = check_boundaries(game)
    moved_blocks = move_blocks(game.active_blocks)
    {_collision_blocks, moved_blocks} = check_collisions(moved_blocks)

    # We need to ensure two opposing players' blocks didn't pass through each other
    #   (swap places).  If they did, we need to remove both blocks.
    final_blocks = hacky_collision_check(moved_blocks)

    game = %GameState{game | active_blocks: final_blocks}

    # Check for end of game (winning condition)
    if Enum.any?(game.scores, fn {_, score} -> score >= Const.points_to_win() end) do
      {:game_over, game}
    else
      {:ok, game}
    end
  end

  @spec outside_boundary?(Block.t()) :: boolean
  def outside_boundary?(%Block{pos: pos, player: player}) do
    # Blocks start outside the board (1 step beyond the boundaries of the board,
    #   appropriate for the direction they are moving).
    {r, c} = CU.from_position_key(pos)

    case player do
      1 -> r < Const.min_row()
      2 -> r > Const.max_row()
      3 -> c < Const.min_col()
      4 -> c > Const.max_col()
    end
  end

  @spec reached_boundary?(Block.t()) :: boolean
  def reached_boundary?(%Block{pos: pos, player: player}) do
    {r, c} = CU.from_position_key(pos)

    case player do
      1 -> r > Const.max_row()
      2 -> r < Const.min_row()
      3 -> c > Const.max_col()
      4 -> c < Const.min_col()
    end
  end
end
