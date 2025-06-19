# lib/elixir_drops/workers/sitemap_generator_worker.ex
defmodule ElixirDrops.Workers.SitemapGeneratorWorker do
  @moduledoc false

  use Oban.Worker, queue: :seo_sitemap, max_attempts: 3

  alias ElixirDrops.Drops
  alias ElixirDrops.Sitemap

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"drop_id" => drop_id}}) do
    case Drops.get_drop(%{drop_id: drop_id}) do
      %Drops.Drop{} = drop ->
        Sitemap.generate(drop)

      nil ->
        {:error, "Drop not found"}
    end
  end

  def perform(%Oban.Job{args: %{}}) do
    Sitemap.generate_full()
  end
end
