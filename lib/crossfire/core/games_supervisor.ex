defmodule Crossfire.Core.GamesSupervisor do
  @moduledoc """
  This module is a supervisor/parent for Games (via their GameManager - aka GameServer).
  """

  use Supervisor

  alias Crossfire.Core.Types
  alias Crossfire.Core.GameManager.State, as: GMState

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    children = [
      # No children started initially; they will be started dynamically.
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @spec start_game(Types.game_server_id(), GMState.t()) :: Supervisor.on_start_child()
  def start_game(game_server_id, state) do
    Supervisor.start_child(__MODULE__, %{
      id: game_server_id,
      start: {Crossfire.Core.GameManager.Server, :start_server, [game_server_id, state]},
      restart: :temporary
    })
  end
end
