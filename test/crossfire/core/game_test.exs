defmodule Crossfire.Core.GameTest do
  use ExUnit.Case, async: true
  alias Crossfire.Core.Game.Block
  alias Crossfire.Core.Game
  alias Crossfire.Core.Game.State, as: GameState

  setup do
    # Setup initial state if needed
    {:ok, initial_state: GameState.new(4)}
  end

  describe "Game.tick/1" do
    test "handles no movement when no active blocks", %{initial_state: state} do
      assert {:ok, state} = Game.tick(state)
      assert state.active_blocks == []
    end

    test "moves blocks on game tick", %{initial_state: state} do
      blocks = [
        %Block{pos: 108, player: 1},
        %Block{pos: 801, player: 2},
        %Block{pos: 101, player: 3},
        %Block{pos: 808, player: 4}
      ]

      next_blocks = [
        %Block{pos: 208, player: 1},
        %Block{pos: 701, player: 2},
        %Block{pos: 102, player: 3},
        %Block{pos: 807, player: 4}
      ]

      state = %{state | active_blocks: blocks}
      {:ok, new_state} = Game.tick(state)

      assert Enum.sort(new_state.active_blocks, &(&1.pos <= &2.pos)) ==
               Enum.sort(next_blocks, &(&1.pos <= &2.pos))
    end

    test "blocks hitting boundary are removed", %{initial_state: state} do
      blocks = [
        %Block{pos: 808, player: 1},
        %Block{pos: 101, player: 2},
        %Block{pos: 108, player: 3},
        %Block{pos: 801, player: 4}
      ]

      state = %{state | active_blocks: blocks}

      {:ok, new_state} = Game.tick(state)

      assert new_state.active_blocks == []
    end

    test "does not detect collisions of 'close calls'", %{initial_state: state} do
      # Four blocks all adjacent to each other, each moving outward but
      #   passing by each other (like a pinwheel).
      #
      # →↓ 31
      # ↑← 24
      blocks = [
        %Block{pos: 404, player: 3},
        %Block{pos: 405, player: 1},
        %Block{pos: 504, player: 2},
        %Block{pos: 505, player: 4}
      ]

      next_blocks = [
        %Block{pos: 404, player: 2},
        %Block{pos: 405, player: 3},
        %Block{pos: 504, player: 4},
        %Block{pos: 505, player: 1}
      ]

      state = %{state | active_blocks: blocks}
      {:ok, new_state} = Game.tick(state)

      assert Enum.sort(new_state.active_blocks, &(&1.pos <= &2.pos)) ==
               Enum.sort(next_blocks, &(&1.pos <= &2.pos))
    end

    test "detects collisions and removes collided blocks", %{initial_state: state} do
      # Head on hits between each pair of players
      # These blocks would cross through each other.
      blocks = [
        %Block{pos: 401, player: 1},
        %Block{pos: 501, player: 2},
        %Block{pos: 104, player: 3},
        %Block{pos: 105, player: 4}
      ]

      state = %{state | active_blocks: blocks}
      {:ok, new_state} = Game.tick(state)

      assert new_state.active_blocks == []

      # Head on hits between each pair of players
      # These blocks would arrive at the same position.
      blocks = [
        %Block{pos: 301, player: 1},
        %Block{pos: 501, player: 2},
        %Block{pos: 103, player: 3},
        %Block{pos: 105, player: 4}
      ]

      state = %{state | active_blocks: blocks}
      {:ok, new_state} = Game.tick(state)

      assert new_state.active_blocks == []

      # Right angle hits between neighboring players.
      # These blocks would arrive at the same position.
      blocks = [
        %Block{pos: 102, player: 1},
        %Block{pos: 201, player: 3},
        %Block{pos: 807, player: 2},
        %Block{pos: 708, player: 4}
      ]

      state = %{state | active_blocks: blocks}
      {:ok, new_state} = Game.tick(state)

      assert new_state.active_blocks == []
    end
  end

  # describe "Game.move_blocks/1" do
  #   test "correctly moves blocks", _context do
  #     blocks = [%{pos: 100, player: 1}]
  #     moved_blocks = Game.move_blocks(blocks)
  #     # Assert each block moved correctly
  #     # Example; adjust according to your move logic
  #     assert moved_blocks == [%{pos: 101, player: 1}]
  #   end
  # end

  # describe "Game.check_collisions/1" do
  #   test "identifies and handles collisions", _context do
  #     blocks = [%{pos: 100, player: 1}, %{pos: 100, player: 2}]
  #     {collided, remaining} = Game.check_collisions(blocks)
  #     assert collided == [%{pos: 100, player: 1}, %{pos: 100, player: 2}]
  #     assert remaining == []
  #   end
  # end
end
