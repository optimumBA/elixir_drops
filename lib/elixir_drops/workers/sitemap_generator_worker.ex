# lib/elixir_drops/workers/sitemap_generator_worker.ex
defmodule ElixirDrops.Workers.SitemapGeneratorWorker do
  @moduledoc false

  use Oban.Worker, queue: :seo, max_attempts: 3

  alias ElixirDrops.Sitemap

  @impl Oban.Worker
  def perform(%Oban.Job{args: _args}) do
    case Sitemap.generate() do
      {:ok, path} -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end
end
