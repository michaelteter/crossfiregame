defmodule Crossfire.Core.Const do
  @moduledoc """
  This module defines constants which are used throughout the project.

  As noted below, some constants should not be changed without corresponding
  changes elsewhere in the code.
  """

  alias Crossfire.Core.Types

  # Game "speed".  tick_interval below 300ms is not evenly playable for
  #   all players (based on their individual network latencies).
  @game_loop_tick_interval 1000

  # How many shots can a player have on the board (or "holding") at once?
  @max_active_shots_per_player 3

  # Max points to win a game.  Game ends when a player reaches this
  #   number of points.
  @points_to_win 15

  # After a game ends, how long does it wait before going *poof*?
  @game_expiration_secs 10

  # After all players arrive and are marked "ready", count down N
  #   seconds before starting the game loop.
  # There's a 1 sec delay before the first tick happens, so an N of
  #   4 means the game starts 5 seconds after all players are ready.
  @countdown_secs 4

  # Constants below here probably cannot be changed without other changes
  #   being made elsewhere in the code.
  @num_players 4

  @min_row 1
  @max_row 8
  @min_col 1
  @max_col 8

  @sec_in_ms 1000

  def countdown_secs, do: @countdown_secs

  def sec_in_ms, do: @sec_in_ms

  def game_loop_tick_interval, do: @game_loop_tick_interval

  def game_expiration_secs, do: @game_expiration_secs

  @game_status_titles %{
    waiting_for_players: "waiting for players",
    countdown: "starting soon",
    playing: "in progress",
    ended: "game over"
  }

  @spec game_status_title(Types.game_status()) :: String.t()
  def game_status_title(status), do: Map.get(@game_status_titles, status)

  def min_row, do: @min_row
  def max_row, do: @max_row
  def min_col, do: @min_col
  def max_col, do: @max_col

  def num_players, do: @num_players

  def max_active_shots_per_player, do: @max_active_shots_per_player

  def points_to_win, do: @points_to_win
end
