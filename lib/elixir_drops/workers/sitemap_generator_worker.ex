# lib/elixir_drops/workers/sitemap_generator_worker.ex
defmodule ElixirDrops.Workers.SitemapGeneratorWorker do
  @moduledoc false

  use Oban.Worker, queue: :seo_sitemap, max_attempts: 3

  alias ElixirDrops.Sitemap

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Sitemap.generate_full()
  end
end
