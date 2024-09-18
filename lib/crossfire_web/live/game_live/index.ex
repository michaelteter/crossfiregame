defmodule CrossfireWeb.GameLive.Index do
  use CrossfireWeb, :live_view

  alias Phoenix.LiveView.Socket

  alias Crossfire.Core.Game
  alias Crossfire.Core.GameManager.State, as: GMState
  alias Crossfire.Core.GameManager.Api, as: GameServer
  alias Crossfire.Core.PubSub, as: Comm
  alias CrossfireWeb.GameLive.Components

  require Crossfire.Core.Util, as: CU

  # ================================================================================================
  # LiveView Functions ============================================================================

  @impl true
  def mount(_params, session, socket) do
    # We arrive here, and then handle_params is called.
    # Set the default socket assigns.
    ua = session["ua"]

    if is_nil(ua) || ua == "" || CU.bot_user_agent?(ua) do
      {:ok, redirect(socket, to: ~p"/bots_go_here")}
    else
      {:ok, default_socket(socket, session["player_id"])}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply,
     case {socket.assigns.live_action, params} do
       {:play, %{"id" => game_id}} -> player_arrival(socket, game_id)
       _ -> socket
     end}
  end

  @impl true
  def handle_event(event, data, socket) do
    event_processing_result =
      case event do
        "abandon_game" -> event_abandon_game(data, socket)
        "shoot" -> event_shoot(data, socket)
        _ -> socket
      end

    {:noreply, event_processing_result}
  end

  @impl true
  def handle_info(msg, socket) do
    CU.lfi("HANDLE_INFO: msg: #{inspect(msg)}")

    # TODO: many of these aren't used; clean up the cases.
    %Socket{} =
      socket =
      case msg do
        :debug_control_back_to_lobby ->
          redirect(socket, to: ~p"/games")

        :game_expired ->
          redirect(socket, to: ~p"/games")

        :self_player_ready ->
          CU.lfi("We got our self-sent player_ready message")
          info_player_ready(socket)

        {:player_ready, _player_num, gmstate} ->
          updated_game_socket(socket, gmstate)

        {:countdown_tick, count_remaining} ->
          info_countdown_tick(count_remaining, socket)

        {:game_loop_tick, gmstate} ->
          info_game_loop_tick(gmstate, socket)

        {:gmstate_updated, gmstate} ->
          updated_game_socket(socket, gmstate)

        {:holding_shots_updated, holding_shots} ->
          info_holding_shots_updated(holding_shots, socket)

        {:player_left, _player_num, gmstate} ->
          info_player_left(gmstate, socket)

        {:game_ended, gmstate} ->
          info_game_ended(gmstate, socket)

        :unsubscribe_from_game ->
          Comm.unsub_from_game(socket.assigns.game_id)
          assign(socket, :subscribed_to_game, false)

        :subscribe_to_game ->
          subscribe_to_game(socket, socket.assigns.game_id)

        unexpected ->
          CU.lfi("=do_handle_info= unexpected: #{inspect(unexpected)}")
          socket
      end

    {:noreply, socket}
  end

  # ================================================================================================
  # Helper Functions ==============================================================================

  defp default_socket(socket, player_id) do
    # TODO: review assigns.  Some are probably outdated and irrelevant.
    socket
    |> assign(game_announcement_message: "☉")
    |> assign(player_ready: false)
    |> assign(gmstate: nil)
    |> assign(countdown: nil)
    |> assign(count_remaining: nil)
    |> assign(pn: 0)
    |> assign(tick_n: 0)
    |> assign(player_id: player_id)
  end

  defp updated_game_socket(socket, gmstate) do
    socket
    |> assign(gmstate: gmstate)
    |> assign(game_id: gmstate.id)
    |> assign(game: gmstate.game)
    |> assign(players: gmstate.players)
    |> assign(holding_shots: Game.holding_shots(gmstate.game) |> CU.list_tuples_to_list_lists())
    |> assign(shots_available: Game.shots_available(gmstate.game))
  end

  # ================================================================================================
  # Handlers: Incoming Messages (info) =============================================================

  defp info_game_ended(gmstate, socket) do
    # :game_over -> "Player #{details[:winner]} won with #{details[:winner_score]} points!"

    {winner, high_score} = winner(gmstate)

    CU.lfi("=info_game_ended= winner: #{winner}, high_score: #{high_score}")

    details = %{winner: winner, high_score: high_score}

    socket
    |> assign(:game_announcement_message, game_announcement_message(:game_over, details))
    |> updated_game_socket(gmstate)
  end

  defp info_countdown_tick(count_remaining, socket) do
    msg =
      case count_remaining do
        0 -> game_announcement_message(:play_started)
        _ -> game_announcement_message(:countdown, %{count_remaining: count_remaining})
      end

    socket
    |> assign(game_announcement_message: msg)
  end

  defp info_holding_shots_updated(holding_shots, socket) do
    socket
    |> assign(:holding_shots, holding_shots |> CU.list_tuples_to_list_lists())
  end

  defp info_game_loop_tick(gmstate, socket) do
    CU.lfi("=info_game_loop_tick=")
    # Update the socket assigns or perform any other necessary actions
    {tick_symbol, tick_n} = tick_symbol(socket.assigns.tick_n)

    socket
    |> assign(:tick_n, tick_n)
    |> assign(:game_announcement_message, tick_symbol)
    |> updated_game_socket(gmstate)
  end

  defp info_player_left(gmstate, socket) do
    msg =
      case gmstate.status do
        :ended -> "A player has quit the game.  The game is over. :("
        :waiting_for_players -> "A player left.  Waiting for replacement."
        _ -> Map.get(socket.assigns, :game_announcement_message, "✧")
      end

    socket
    |> assign(:game_announcement_message, msg)
    |> updated_game_socket(gmstate)
  end

  defp info_player_ready(socket) do
    game_id = socket.assigns.game_id
    player_id = socket.assigns.player_id

    returned_status_atom = GameServer.player_ready(game_id, player_id)

    case returned_status_atom do
      :ok ->
        socket

      :game_not_found ->
        socket
        |> put_flash(:error, "Game not found.")
        |> redirect(to: ~p"/games")

      error ->
        socket
        |> put_flash(:error, "Error: #{inspect(error)}")
    end
  end

  # ================================================================================================
  # Handlers: Events ===============================================================================

  defp event_abandon_game(%{"game_id" => game_id}, socket) do
    GameServer.abandon_game(game_id, socket.assigns.player_id)

    socket
    |> redirect(to: ~p"/games")
  end

  defp event_shoot(%{"slot" => slot}, socket) do
    player = socket.assigns.pn
    slot = if is_binary(slot), do: String.to_integer(slot), else: slot

    GameServer.shoot(socket.assigns.game_id, player, slot)
    socket
  end

  # ================================================================================================
  # Helper Functions ==============================================================================

  defp player_arrival(socket, game_id) when is_binary(game_id) do
    case GameServer.get_game(game_id) do
      {:ok, %GMState{} = gmstate} ->
        CU.lfi("we got the game via the game_id, now we call our other player_arrival function")
        player_arrival(socket, gmstate)

      :game_not_found ->
        socket
        |> put_flash(:error, "Player Arrival: Game not found")
        |> redirect(to: ~p"/games")

      error ->
        socket
        |> put_flash(:error, "Player Arrival: Error: #{inspect(error)}")
        |> redirect(to: ~p"/games")
    end
  end

  defp player_arrival(socket, %GMState{} = gmstate) do
    CU.lfi("2nd level player_arrival with gmstate: #{inspect(gmstate)}")
    player_num = GameServer.player_num(gmstate.players, socket.assigns.player_id)

    if player_num == 0 do
      # Player isn't in this game, so don't make them ready or do anything.
      # Let them be an observer I guess...?
      # Defer for now; redirect.
      socket
      |> put_flash(
        :error,
        "You are not a player in this game, and observation is not implemented yet; sorry!"
      )
      |> redirect(to: ~p"/games")
    else
      player_ready = Map.get(socket.assigns, :player_ready, false)

      socket =
        if player_ready do
          CU.lfi("(player was already ready, so we just return unchanged socket)")
          socket
        else
          CU.lfi("Doing stuff to mark this player as ready")
          socket = assign(socket, :player_ready, true)
          CU.lfi("Sending ourselves a :self_player_ready message")
          Process.send(self(), :self_player_ready, [])
          socket
        end

      socket
      |> subscribe_to_game(gmstate.id)
      |> assign(pn: GameServer.player_num(gmstate.players, socket.assigns.player_id))
      |> updated_game_socket(gmstate)
    end
  end

  def subscribe_to_game(socket, game_id) do
    # Extra effort to try to avoid multiple subscriptions to the same topic.
    if connected?(socket) do
      if Map.get(socket.assigns, :subscribed_to_game, false) do
        socket
      else
        Comm.unsub_from_game(game_id)
        Comm.sub_to_game(game_id)
        Comm.unsub_from_debug_control()
        Comm.sub_to_debug_control()
        assign(socket, :subscribed_to_game, true)
      end
    else
      # CU.lfi("=subscribe_to_game= not connected")
      assign(socket, :subscribed_to_game, false)
    end
  end

  def winner(gmstate) do
    scores = gmstate.game.scores

    rev =
      Enum.reduce(scores, %{}, fn {pn, score}, acc ->
        Map.update(acc, score, [pn], &[pn | &1])
      end)

    high_score = Enum.max(Map.keys(rev))

    winner =
      rev[high_score]
      |> Enum.map(&Integer.to_string/1)
      |> Enum.join(" & ")

    {winner, high_score}
  end

  def game_announcement_message(game_announcement, details \\ %{}) do
    case game_announcement do
      :player_left -> "Player #{details[:player_num]} left the game.  Waiting for players."
      :waiting_for_players -> "Waiting for players"
      :countdown -> "Game starts in #{details[:count_remaining]}"
      :play_started -> "Game started!"
      :tick -> "Tick: #{inspect(details)}"
      :game_over -> "Player #{details[:winner]} won with #{details[:high_score]} points!"
      _ -> ""
    end
  end

  @tick_symbols {"-", "\\", "|", "/"}

  def tick_symbol(n), do: {elem(@tick_symbols, n), rem(n + 1, 4)}
end
