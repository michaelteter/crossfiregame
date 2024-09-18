defmodule CrossfireWeb.LobbyLive.Index do
  use CrossfireWeb, :live_view

  alias Crossfire.Core.Const
  alias Crossfire.Core.Game
  alias Crossfire.Core.GameMetadata
  alias Crossfire.Core.Lobby.Api, as: LobbyServer
  alias Crossfire.Core.PubSub, as: Comm
  alias Crossfire.Core.GameManager.Api, as: GameServer

  require Crossfire.Core.Util, as: CU

  # -----------------------------------------------------------------------------
  # LiveView --------------------------------------------------------------------

  @impl true
  def mount(_params, session, socket),
    do: {:ok, do_mount(socket, session["player_id"], session["ua"])}

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply,
     case {socket.assigns.live_action, params} do
       {:join, %{"id" => game_id}} ->
         event_join_game(game_id, socket)

       _ ->
         socket
     end}
  end

  @impl true
  def handle_info(msg, socket) do
    CU.lfi("=handle_info= msg: #{inspect(msg)}")

    {:noreply,
     case msg do
       {:new_game_exists, game_metadata} -> info_new_game_exists(game_metadata, socket)
       {:private_game_created, m} -> info_new_game_exists(m, socket)
       {:game_metadata_updated, game_metadata} -> info_game_updated(game_metadata, socket)
       {:game_expired, game_id} -> info_game_expired(game_id, socket)
       # TODO: go figure out who is sending this _bleh message and why
       {{:game_expired, game_id}, _bleh} -> info_game_expired(game_id, socket)
       _ -> put_flash(socket, :error, "Unknown message: #{inspect(msg)}")
     end}
  end

  @impl true
  def handle_event(event, data, socket) do
    CU.lfi("=handle_event= event: #{inspect(event)}, data: #{inspect(data)}")

    {:noreply,
     case event do
       "create_new_game" -> event_create_new_game(data["visibility"], data["bot-count"], socket)
       "abandon_game" -> event_abandon_game(data["game_id"], socket)
       "play_game" -> event_join_game(data["game_id"], socket)
       "join_game" -> event_join_game(data["game_id"], socket)
       "update_bot_count" -> event_update_bot_count(data["bot_count"], socket)
       _ -> put_flash(socket, :error, "Unknown event: #{inspect(event)}")
     end}
  end

  # -----------------------------------------------------------------------------
  # Mount -----------------------------------------------------------------------

  def do_mount(socket, player_id, user_agent) do
    # cond is used here instead of overloading do_mount() because I usually don't like
    #   "cases" scattered across multiple functions.  If the implemention of each case
    #   below were lengthy, I would move the implementation to its own individually named
    #   function.
    cond do
      is_nil(player_id) ->
        socket
        |> put_flash(:error, "Unable to join lobby.  Do you have cookies enabled?")
        |> redirect(to: "/")

      CU.bot_user_agent?(user_agent) ->
        socket
        |> redirect(to: "/bots_go_here")

      true ->
        case LobbyServer.list_games(player_id) do
          {:ok, games} ->
            socket
            |> assign(bot_count: 0)
            |> assign(player_id: player_id)
            |> assign(user_agent: user_agent)
            |> stream(:games, games)
            |> assign(owned_games: owned_games(games))
            |> assign(joined_games: joined_games(games))
            |> assign(can_create_private_game: can_create_game?(games, player_id, :private))
            |> assign(can_create_public_game: can_create_game?(games, player_id, :public))
            |> subscribe_to_player()
            |> subscribe_to_public_games_list()

          _ ->
            socket
            |> put_flash(:error, "There was a problem joining the Lobby.")
            |> redirect(to: "/")
        end
    end
  end

  # -----------------------------------------------------------------------------
  # Info (msg) Handlers ---------------------------------------------------------

  def info_new_game_exists(game_metadata, socket) do
    CU.lfi("=info_new_game_exists= game_metadata: #{inspect(game_metadata)}")

    # The new game requested has been created, and the LobbyServer has broadcasted the game (server) to us.
    m = update_player_role(game_metadata, socket.assigns.player_id)
    CU.lfi("  Player Role: #{m.player_role}")

    if m.player_role == :owner do
      redirect(socket, to: ~p"/games/#{m.id}/play")
    else
      # If we are not the owner, we need to update our games list.
      stream_insert(socket, :games, m)
    end
  end

  def info_game_expired(game_id, socket) do
    # Received broadcast that a game has expired.
    # We need to update our games list.
    # stream_delete expects a game metadata struct, but we can just provide the minimal necessary id.
    stream_delete(socket, :games, %{id: game_id})
  end

  def info_game_updated(game_metadata, socket) do
    # Received broadcast that a game has been updated.
    m = game_metadata |> update_player_role(socket.assigns.player_id)

    case m.player_role do
      :owner ->
        socket
        |> update_can_create_games(m)
        |> assign(:owned_games, Map.put(socket.assigns.owned_games, m.id, m))
        |> stream_insert(:games, m)

      :player ->
        # If we receive this "private" (game topic) message, it means we tried
        #   to join the game.  Now that we have joined, we can either update
        #   the game on our Lobby page or just redirect to the GameLive page.
        redirect(socket, to: ~p"/games/#{m.id}/play")

      _ ->
        if m.visibility == :public, do: stream_insert(socket, :games, m), else: socket
    end
  end

  # -----------------------------------------------------------------------------
  # Event Handlers --------------------------------------------------------------

  defp event_create_new_game(visibility, bot_count, socket) do
    # User has clicked [New Public/Private Game]
    # TODO: handle errors

    n_bots =
      cond do
        is_integer(bot_count) -> bot_count
        is_binary(bot_count) -> String.to_integer(bot_count)
        true -> 0
      end

    LobbyServer.create_new_game(socket.assigns.player_id, String.to_atom(visibility), n_bots)
    socket
  end

  defp event_abandon_game(game_id, socket) do
    GameServer.abandon_game(game_id, socket.assigns.player_id)

    # TODO: this is a cop-out, redirecting.
    #   The issue is that the can_create_game stuff isn't being updated, and is
    #   probably poorly designed anyway.
    socket
    |> redirect(to: ~p"/games")
  end

  defp event_join_game(game_id, socket) do
    player_id = socket.assigns.player_id

    case GameServer.join_game(game_id, player_id) do
      :ok ->
        socket
        |> redirect(to: ~p"/games/#{game_id}/play")

      :game_not_found ->
        put_flash(socket, :error, "Game not found")

      :game_full ->
        put_flash(socket, :error, "Game is full")
    end
  end

  defp event_update_bot_count(bot_count, socket) do
    n_bots =
      case Integer.parse(bot_count) do
        :error -> 0
        {bot_count, _} -> bot_count
      end

    socket
    |> assign(bot_count: n_bots)
  end

  # -----------------------------------------------------------------------------
  # Private functions -----------------------------------------------------------

  def subscribe_to_player(socket) do
    player_id = Map.get(socket.assigns, :player_id)

    if !is_nil(player_id) && connected?(socket) do
      if Map.get(socket.assigns, :subscribed_to_my_topic, false) do
        socket
      else
        # Just to be safe
        Comm.unsub_from_player(player_id)
        Comm.sub_to_player(player_id)
        assign(socket, :subscribed_to_my_topic, true)
      end
    else
      assign(socket, :subscribed_to_my_topic, false)
    end
  end

  def subscribe_to_my_game(socket) do
    game = Map.get(socket.assigns, :my_game)

    if !is_nil(game) && connected?(socket) do
      if Map.get(socket.assigns, :subscribed_to_my_game, false) do
        socket
      else
        # Just to be safe
        Comm.unsub_from_game(game.id)
        Comm.sub_to_game(game.id)
        assign(socket, :subscribed_to_my_game, true)
      end
    else
      assign(socket, :subscribed_to_my_game, false)
    end
  end

  def subscribe_to_public_games_list(socket) do
    if connected?(socket) do
      if Map.get(socket.assigns, :subscribed_to_public_games_list, false) do
        socket
      else
        Comm.unsub_from_games_list()
        Comm.sub_to_games_list()
        assign(socket, :subscribed_to_public_games_list, true)
      end
    else
      assign(socket, :subscribed_to_public_games_list, false)
    end
  end

  defp games_by_role(games, role) do
    games
    |> Enum.filter(fn game -> game.player_role == role end)
    |> Enum.into(%{}, fn game -> {game.id, game} end)
  end

  defp owned_games(games), do: games_by_role(games, :owner)
  defp joined_games(games), do: games_by_role(games, :player)

  defp owned_game_empty?(game, player_id, visibility) do
    game.player_role == :owner &&
      game.visibility == visibility &&
      Enum.count(Game.other_players(game.players, player_id)) == 0
  end

  defp can_create_game?(games, player_id, visibility) do
    !Enum.any?(games, fn game ->
      owned_game_empty?(game, player_id, visibility)
    end)
  end

  defp update_can_create_games(socket, game_metadata) do
    player_id = socket.assigns.player_id
    cc_priv = socket.assigns.can_create_private_game
    cc_pub = socket.assigns.can_create_public_game

    {cc_priv, cc_pub} =
      case game_metadata.visibility do
        :private -> {!owned_game_empty?(game_metadata, player_id, :private), cc_pub}
        :public -> {cc_priv, !owned_game_empty?(game_metadata, player_id, :public)}
        _ -> {cc_priv, cc_pub}
      end

    socket
    |> assign(can_create_private_game: cc_priv)
    |> assign(can_create_public_game: cc_pub)
  end

  defp update_player_role(game_metadata, player_id) do
    player_role =
      if game_metadata.owner_id == player_id do
        :owner
      else
        case Enum.find(game_metadata.players, fn {_, v} -> v == player_id end) do
          nil -> :none
          _ -> :player
        end
      end

    %GameMetadata{game_metadata | player_role: player_role}
  end
end
