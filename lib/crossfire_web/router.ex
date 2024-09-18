defmodule CrossfireWeb.Router do
  use CrossfireWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(CrossfireWeb.Plugs.BadActorRedirect)
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(CrossfireWeb.Plugs.PlayerID)
    plug(:put_root_layout, html: {CrossfireWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", CrossfireWeb do
    pipe_through(:browser)

    get("/", PageController, :home)
    get("/bots_go_here", BotController, :index)

    live("/games", LobbyLive.Index)
    live("/games/:id/join", LobbyLive.Index, :join)
    live("/games/:id/play", GameLive.Index, :play)

    # live("/games/:id/observe", GameLive.Index, :observe)
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:crossfire, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: CrossfireWeb.Telemetry)
      # forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
