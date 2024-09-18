defmodule Crossfire.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CrossfireWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:crossfire, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Crossfire.PubSub},
      # {Finch, name: Crossfire.Finch},
      CrossfireWeb.Endpoint,
      Crossfire.Core.Lobby.Server,
      Crossfire.Core.GamesSupervisor,
      Crossfire.Core.AlphaIdServer
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Crossfire.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CrossfireWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
