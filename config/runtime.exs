import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/elixir_drops start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :elixir_drops, ElixirDropsWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :elixir_drops, ElixirDrops.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :elixir_drops, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :elixir_drops, ElixirDropsWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :elixir_drops, ElixirDropsWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :elixir_drops, ElixirDropsWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :elixir_drops, ElixirDrops.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.

  github_client_id =
    System.get_env("GITHUB_CLIENT_ID") ||
      raise """
      environment variable GITHUB_CLIENT_ID is missing.
      """

  github_client_secret =
    System.get_env("GITHUB_CLIENT_SECRET") ||
      raise """
      environment variable GITHUB_CLIENT_SECRET is missing.
      """

  config :ueberauth, Ueberauth.Strategy.Github.OAuth,
    client_id: github_client_id,
    client_secret: github_client_secret

  appsignal_app_env =
    System.get_env("APPSIGNAL_APP_ENV") ||
      raise """
      environment variable APPSIGNAL_APP_ENV is missing.
      """

  appsignal_push_api_key =
    System.get_env("APPSIGNAL_PUSH_API_KEY") ||
      raise """
      environment variable APPSIGNAL_PUSH_API_KEY is missing.
      """

  revision_file = Path.join([:code.priv_dir(:elixir_drops), "REVISION"])

  appsignal_revision =
    revision_file
    |> File.read!()
    |> String.trim()

  config :appsignal, :config,
    env: appsignal_app_env,
    push_api_key: appsignal_push_api_key,
    revision: appsignal_revision

  # Wallaby auth
  wallaby_auth_username =
    System.get_env("WALLABY_AUTH_USERNAME") ||
      raise """
      environment variable WALLABY_AUTH_USERNAME is missing.
      """

  wallaby_auth_password =
    System.get_env("WALLABY_AUTH_PASSWORD") ||
      raise """
      environment variable WALLABY_AUTH_PASSWORD is missing.
      """

  config :elixir_drops,
    wallaby_auth: [
      username: wallaby_auth_username,
      password: wallaby_auth_password
    ]

  aws_access_key_id =
    System.get_env("AWS_ACCESS_KEY_ID") ||
      raise """
      environment variable AWS_ACCESS_KEY_ID is missing.
      """

  aws_bucket =
    System.get_env("BUCKET_NAME") ||
      raise """
      environment variable AWS_BUCKET_NAME is missing.
      """

  aws_endpoint_url =
    System.get_env("AWS_ENDPOINT_URL_S3") ||
      raise """
      environment variable AWS_ENDPOINT_URL_S3 is missing.
      """

  aws_region =
    System.get_env("AWS_REGION") ||
      raise """
      environment variable AWS_REGION is missing.
      """

  aws_secret_access_key =
    System.get_env("AWS_SECRET_ACCESS_KEY") ||
      raise """
      environment variable AWS_SECRET_ACCESS_KEY is missing.
      """

  config :elixir_drops, :s3,
    debug_requests: true,
    access_key_id: aws_access_key_id,
    bucket: aws_bucket,
    endpoint_url: aws_endpoint_url,
    region: aws_region,
    secret_access_key: aws_secret_access_key

  # fly_api_token =
  #   System.get_env("FLY_API_TOKEN") ||
  #     raise """
  #     environment variable FLY_API_TOKEN is missing.
  #     """

  config :flame, :backend, FLAME.FlyBackend

  config :flame, FLAME.FlyBackend,
    cpu_kind: "shared",
    env: %{
      "APPSIGNAL_APP_ENV" => appsignal_app_env,
      "APPSIGNAL_PUSH_API_KEY" => appsignal_push_api_key,
      "AWS_ACCESS_KEY_ID" => aws_access_key_id,
      "AWS_ENDPOINT_URL_S3" => aws_endpoint_url,
      "AWS_REGION" => aws_region,
      "AWS_SECRET_ACCESS_KEY" => aws_secret_access_key,
      "BUCKET_NAME" => aws_bucket,
      "WALLABY_AUTH_USERNAME" => wallaby_auth_username,
      "WALLABY_AUTH_PASSWORD" => wallaby_auth_password
    },
    memory_mb: 1024,
    token: System.get_env("FLY_API_TOKEN")
end
