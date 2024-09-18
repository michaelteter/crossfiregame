# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# config :crossfire,
#   ecto_repos: [Crossfire.Repo],
#   generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :crossfire, CrossfireWeb.Endpoint,
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: CrossfireWeb.ErrorHTML, json: CrossfireWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Crossfire.PubSub,
  live_view: [signing_salt: "bmtJPYSW"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :crossfire, Crossfire.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  crossfire: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.0",
  crossfire: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :logger, :console,
  format: "[$level] $message\n",
  metadata: [:module]

config :crossfire, :base_url, "http://localhost:4000"
config :crossfire, :dev_or_prod, :dev

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
