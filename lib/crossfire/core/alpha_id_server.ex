defmodule Crossfire.Core.AlphaIdServer do
  @moduledoc """
  This module provides a service for generating unique IDs.

  These IDs are all uppercase letters, except for I and O, which are excluded
  to avoid confusion with 1 and 0.

  Game IDs are 4 characters long, and player IDs are 5 characters long.
  The difference in length is to make it easier to distinguish between the two,
  and the possible number of IDs is appropriate for each use case.
  """

  use GenServer

  @alphabet Enum.map(?A..?Z, fn char -> <<char>> end)
            |> Enum.reject(&(&1 in ["I", "O"]))
  @player_id_length 5
  @game_id_length 4

  # Client API XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_unique_id do
    GenServer.call(__MODULE__, {:get_unique_id, :game})
  end

  def new_player_id do
    GenServer.call(__MODULE__, {:get_unique_id, :player})
  end

  def new_game_id do
    GenServer.call(__MODULE__, {:get_unique_id, :game})
  end

  def expire_id(code) do
    GenServer.cast(__MODULE__, {:expire_id, code})
  end

  def get_ids do
    GenServer.call(__MODULE__, :get_ids)
  end

  def flush_ids do
    GenServer.cast(__MODULE__, :flush_ids)
  end

  # Server XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

  @impl true
  def init(state) do
    {:ok, Map.put(state, :used_ids, MapSet.new())}
  end

  @impl true
  def handle_call({:get_unique_id, player_or_game}, _from, state) do
    used_ids = Map.get(state, :used_ids)
    {new_id, updated_ids} = generate_unique_id(player_or_game, used_ids)
    {:reply, new_id, Map.put(state, :used_ids, updated_ids)}
  end

  @impl true
  def handle_call(:get_ids, _from, state) do
    used_ids = Map.get(state, :used_ids)
    {:reply, MapSet.to_list(used_ids), state}
  end

  @impl true
  def handle_cast(:flush_ids, state) do
    {:noreply, Map.put(state, :used_ids, MapSet.new())}
  end

  @impl true
  def handle_cast({:expire_id, code}, state) do
    used_ids = Map.get(state, :used_ids)
    {:noreply, Map.put(state, :used_ids, MapSet.delete(used_ids, code))}
  end

  # Internal XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

  defp generate_unique_id(player_or_game, used_ids) do
    length =
      case player_or_game do
        :player -> @player_id_length
        :game -> @game_id_length
      end

    new_id = generate_code(length)

    if MapSet.member?(used_ids, new_id) do
      generate_unique_id(player_or_game, used_ids)
    else
      {new_id, MapSet.put(used_ids, new_id)}
    end
  end

  defp generate_code(length) do
    1..length
    |> Enum.map(fn _ -> Enum.random(@alphabet) end)
    |> Enum.join()
  end
end
