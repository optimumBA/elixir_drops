defmodule ElixirDrops.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    children =
      children(
        always: ElixirDropsWeb.Telemetry,
        always: ElixirDropsWeb.Endpoint,
        always: ElixirDrops.Repo,
        always: {Phoenix.PubSub, name: ElixirDrops.PubSub},
        parent:
          {DNSCluster, query: Application.get_env(:elixir_drops, :dns_cluster_query) || :ignore},
        # Start the Finch HTTP client for sending emails
        parent: {Finch, name: ElixirDrops.Finch},
        # Start a worker by calling: ElixirDrops.Worker.start_link(arg)
        # {ElixirDrops.Worker, arg},
        # Start to serve requests, typically the last entry
        parent:
          {FLAME.Pool,
           name: ElixirDrops.ScreenshotGenerator,
           idle_shutdown_after: 120_000,
           log: :info,
           max_concurrency: 1,
           max: 1,
           min: 0},
        parent: {Oban, Application.get_env(:elixir_drops, Oban)}
      )

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

  # Exclude children marked with `parent` in the FLAME environment
  defp children(child_specs) do
    is_parent? = is_nil(FLAME.Parent.get())
    is_flame? = !is_parent? || FLAME.Backend.impl() == FLAME.LocalBackend

    Enum.flat_map(child_specs, fn
      {:always, spec} -> [spec]
      {:parent, spec} when is_parent? == true -> [spec]
      {:parent, _spec} when is_parent? == false -> []
      {:flame, spec} when is_flame? == true -> [spec]
      {:flame, _spec} when is_flame? == false -> []
    end)
  end
end
