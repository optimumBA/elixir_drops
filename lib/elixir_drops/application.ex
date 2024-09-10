defmodule ElixirDrops.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    flame_parent = FLAME.Parent.get()

    app_children = [
      ElixirDropsWeb.Telemetry,
      ElixirDrops.Repo,
      {DNSCluster, query: Application.get_env(:elixir_drops, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ElixirDrops.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: ElixirDrops.Finch},
      # Start a worker by calling: ElixirDrops.Worker.start_link(arg)
      # {ElixirDrops.Worker, arg},
      # Start to serve requests, typically the last entry
      {Oban, Application.fetch_env!(:elixir_drops, Oban)},
      {
        FLAME.Pool,
        name: ElixirDrops.ScreenshotGenerator,
        idle_shutdown_after: 30_000,
        log: :info,
        max_concurrency: 10,
        max: 20,
        min: 0
      },
      !flame_parent && ElixirDropsWeb.Endpoint
    ]

    children = Enum.filter(app_children, & &1)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ElixirDrops.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    ElixirDropsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
