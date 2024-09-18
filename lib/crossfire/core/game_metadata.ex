defmodule Crossfire.Core.GameMetadata do
  @moduledoc """
  Module for defining the metadata of a game.

  This is the data provided by GameManager for the Lobby.  It is
  similar to GameManager.State, but it has some extra convenience
  properties (and is lacking some unnecessary properties).
  """

  alias Crossfire.Core.Types

  @type t :: %__MODULE__{
          # Set by LobbyServer.
          id: Types.game_id(),
          pid: pid(),
          owner_id: Types.player_id(),
          visibility: Types.game_visibility(),

          # Copied or derived from game state.
          status: Types.game_status(),
          players: Types.players(),
          player_count: integer,
          players_ready: MapSet.t(Types.player_num()),

          # Used by client for games list display and player action buttons.
          player_role: Types.player_role()
        }

  defstruct(
    id: "",
    pid: nil,
    owner_id: "",
    visibility: :private,
    status: :waiting_for_players,
    players: %{},
    player_count: 0,
    players_ready: MapSet.new(),
    player_role: :none
  )
end
