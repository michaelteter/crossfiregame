defmodule CrossfireWeb.GameLive.Components do
  use CrossfireWeb, :html

  alias CrossfireWeb.Graphics, as: Gfx

  attr(:pn, :integer, required: true)
  attr(:players_ready, :list, required: true)
  attr(:game_status, :atom, required: true)
  attr(:scores, :map, default: %{1 => 0, 2 => 0, 3 => 0, 4 => 0})

  def scoreboard(assigns) do
    ~H"""
      <div class={"flex flex-row w-#{Gfx.row_w + 2} mb-6"}>
        <%= for player <- 1..4 do %>
          <div class={Gfx.player_scorebox_class(player, @pn) <> " m-1 flex flex-col flex items-center justify-center text-black"}>
            <div class={"#{Gfx.player_scorebox_bg_color(player)} flex items-center justify-center h-10 text-black px-2 py-1"}>
              <span class={Gfx.player_scorebox_font_class(player, @pn)}>Player <%= player %></span>
            </div>
            <div class={"border border-l-0 border-r-0 border-b-0 border-gray-600 bg-gray-100 flex items-center justify-center w-full h-7 text-black px-2 py-1"}>
              <span class={Gfx.player_scorebox_font_class(player, @pn)}>
                <%= if @game_status in [:waiting_for_players] && player in @players_ready do %>
                  Ready
                <% else %>
                  <%= Gfx.player_score_number(Map.get(@scores, player)) %>
                <% end %>
              </span>
            </div>
          </div>
        <% end %>
      </div>
    """
  end
end
