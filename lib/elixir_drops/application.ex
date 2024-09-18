defmodule ElixirDrops.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      ElixirDropsWeb.Telemetry,
      ElixirDrops.Repo,
      {DNSCluster, query: Application.get_env(:elixir_drops, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ElixirDrops.PubSub},

      # Start the Finch HTTP client for sending emails
      {Finch, name: ElixirDrops.Finch},

      # Start a worker by calling: ElixirDrops.Worker.start_link(arg)
      # {ElixirDrops.Worker, arg},
      # Start to serve requests, typically the last entry
      ElixirDropsWeb.Endpoint,
      {Oban, Application.fetch_env!(:elixir_drops, Oban)}
    ]

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
