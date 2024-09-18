defmodule CrossfireWeb.Graphics do
  @moduledoc """
  Constants and functions for graphics and layout.

  Most of this is probably unused since we moved from html-based
  rendering to a canvas-based rendering system.
  """

  alias Crossfire.Core.Const, as: C

  @square_side_length 100

  def row_w, do: C.max_col() * @square_side_length
  def col_h, do: C.max_row() * @square_side_length

  def cell_w, do: @square_side_length
  def cell_h, do: @square_side_length

  def board_w, do: C.max_col() * @square_side_length

  # def player_slot_button_width,  do: @square_side_length
  # def player_slot_button_height, do: @square_side_length
  # def board_cell_width,          do: @square_side_length
  # def board_cell_height,         do: @square_side_length

  def player_scorebox_bg_color(player) do
    case player do
      1 -> "bg-red-400"
      2 -> "bg-blue-400"
      3 -> "bg-green-400"
      4 -> "bg-yellow-400"
      _ -> "bg-gray-200"
    end
  end

  def player_bg_color(player) do
    case player do
      1 -> "bg-red-500"
      2 -> "bg-blue-500"
      3 -> "bg-green-500"
      4 -> "bg-yellow-500"
      _ -> "bg-gray-200"
    end
  end

  def player_text_color(player) do
    case player do
      1 -> "text-red-900"
      2 -> "text-blue-900"
      3 -> "text-green-900"
      4 -> "text-yellow-900"
      _ -> "text-gray-900"
    end
  end

  def player_hover_color(player) do
    case player do
      1 -> "hover:bg-red-700"
      2 -> "hover:bg-blue-700"
      3 -> "hover:bg-green-700"
      4 -> "hover:bg-yellow-700"
      _ -> "hover:bg-gray-700"
    end
  end

  def player_holding_bg_color(player) do
    case player do
      1 -> "bg-red-200"
      2 -> "bg-blue-200"
      3 -> "bg-green-200"
      4 -> "bg-yellow-200"
      _ -> "bg-gray-200"
    end
  end

  def div_slot_class_base do
    "w-10 h-10 flex items-center justify-center text-sm font-bold"
  end

  def div_shot_holding_class(player) do
    "#{div_slot_class_base()} border-2 border-dotted border-black #{player_text_color(player)} #{player_holding_bg_color(player)}"
  end

  def div_can_shoot_class(player) do
    # "#{div_slot_class_base()} #{player_text_color(player)} #{player_bg_color(player)} #{player_hover_color(player)}"
    "#{div_slot_class_base()} border border-zinc-200 border-solid #{player_text_color(player)} #{player_bg_color(player)} #{player_hover_color(player)}"
  end

  def div_cannot_shoot_class(player) do
    # "#{div_slot_class_base()} #{player_text_color(player)} #{player_bg_color(player)}"
    "#{div_slot_class_base()} border border-zinc-200 border-solid #{player_text_color(player)} #{player_bg_color(player)}"
  end

  def div_player_inactive_class(_player) do
    "#{div_slot_class_base()} border border-zinc-200 border-solid bg-zinc-300"
  end

  def player_block_symbol(player_num) do
    case player_num do
      1 -> "↓"
      2 -> "↑"
      3 -> "→"
      4 -> "←"
      _ -> ""
    end
  end

  def player_slot_symbol(_board_loc) do
    "·"
  end

  def player_slot_symbol(board_loc, :loaded) do
    player_block_symbol(board_loc)
  end

  def player_slot_symbol(board_loc, :can_shoot) do
    case board_loc do
      :top -> "⇣"
      :bottom -> "⇡"
      :left -> "⇢"
      :right -> "⇠"
      _ -> ""
    end
  end

  def player_score_number(0), do: "·"
  def player_score_number(score), do: score

  def player_slot_button_class(player, pn) do
    if pn == player do
      "border border-gray-900 bg-gray-800"
    else
      "border border-gray-300 bg-gray-200"
    end
  end

  def player_scorebox_font_class(player, pn) do
    if pn == player do
      "font-bold"
    else
      ""
    end
  end

  def player_scorebox_class(player, pn) do
    if pn == player do
      "border border-gray-900"
    else
      "border border-gray-400"
    end
  end
end
