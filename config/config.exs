# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :elixir_drops,
  ecto_repos: [ElixirDrops.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configures the endpoint
config :elixir_drops, ElixirDropsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ElixirDropsWeb.ErrorHTML, json: ElixirDropsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ElixirDrops.PubSub,
  live_view: [signing_salt: "RieadJsi"]

config :wallaby,
  chromedriver: [
    headless: true
  ],
  hackney_options: [
    recv_timeout: 60_000,
    timeout: 60_000
  ],
  max_wait_time: 10_000,
  screenshot_on_failure: true

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :elixir_drops, ElixirDrops.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  elixir_drops: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  elixir_drops: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# AppSignal
config :appsignal, :config,
  active: false,
  ecto_repos: [ElixirDrops.Repo],
  env: config_env(),
  ignore_actions: ["ElixirDropsWeb.HealthController#index"],
  name: "elixir_drops",
  otp_app: :elixir_drops

# register Github strategy with Ueberauth
config :ueberauth, Ueberauth,
  providers: [
    github:
      {Ueberauth.Strategy.Github,
       [
         default_scope: "read:user,user:email"
       ]}
  ]

config :elixir_drops, Oban,
  engine: Oban.Engines.Basic,
  queues: [default: 10, seo_images: 1, seo_sitemap: 1],
  repo: ElixirDrops.Repo

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
