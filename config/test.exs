import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :elixir_drops, ElixirDrops.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "elixir_drops_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: min(System.schedulers_online() * 2, 20),
  queue_target: 5000,
  queue_interval: 10_000,
  timeout: 60_000

# Get test port from environment or use default
test_port = String.to_integer(System.get_env("PORT_TEST") || "4100")

# Only start server for feature tests to avoid unnecessary overhead
# Server is needed for PhoenixTest.Playwright browser automation
server_enabled? = System.get_env("FEATURE_TESTS") == "true"

config :elixir_drops, ElixirDropsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: test_port],
  secret_key_base: "VwmzCly3NO1QYT8AFbHvceC6eRjzjJK+d7B//nUvmfNaP3xfGE3QSn+gc2rK4rUe",
  server: server_enabled?,
  url: [host: "localhost", port: test_port]

# In test we don't send emails
config :elixir_drops, ElixirDrops.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :elixir_drops, Oban, testing: :manual

config :elixir_drops, :dev_auth_bypass, true
config :elixir_drops, dev_routes: true

# PhoenixTest.Playwright configuration
config :phoenix_test,
  driver: PhoenixTest.Playwright,
  endpoint: ElixirDropsWeb.Endpoint,
  otp_app: :elixir_drops,
  playwright: [
    browser: :chromium,
    browser_launch_timeout: 30_000,
    headless: System.get_env("PW_HEADLESS", "true") == "true",
    js_logger: false,
    screenshot: System.get_env("PW_SCREENSHOT", "false") == "true",
    timeout: System.get_env("PW_TIMEOUT", "500") |> String.to_integer(),
    trace: System.get_env("PW_TRACE", "false") == "true"
  ]

config :elixir_drops,
  wallaby_auth: [
    username: "test_elixir_drops_wallaby",
    password: "test_password"
  ]

# Enable SQL Sandbox for concurrent browser testing (Phoenix.Ecto.SQL.Sandbox pattern)
config :elixir_drops, :sql_sandbox, true
