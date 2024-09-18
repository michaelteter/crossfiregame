defmodule Crossfire.Core.Types do
  @moduledoc """
  Module for defining types used in Crossfire.
  """

  @type topic :: String.t()
  @type player_id :: String.t()
  @type player_num :: integer
  @type players :: %{player_num => player_id}
  @type player_list :: [player_id]
  @type player_role :: :none | :owner | :player
  @type slot :: integer
  @type game_id :: String.t()
  @type game_server_id :: atom

  @type timer_type :: nil | :countdown | :game_loop | :expiration

  @type game_visibility :: :public | :private
  @type game_status :: :waiting_for_players | :countdown | :playing | :ended

  @type board_row :: integer
  @type board_col :: integer
  @type board_pos :: integer
end
