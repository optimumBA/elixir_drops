# lib/elixir_drops/workers/sitemap_generator_worker.ex
defmodule ElixirDrops.Workers.SitemapGeneratorWorker do
  @moduledoc false

  use Oban.Worker, queue: :seo_sitemap, max_attempts: 3

  alias ElixirDrops.Drops
  alias ElixirDrops.Sitemap

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    case Drops.get_drop(%{drop_id: args["drop_id"]}) do
      nil ->
        {:error, "Drop not found"}

      drop ->
        Sitemap.generate(drop)
    end
  end
end
