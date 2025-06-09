defmodule ElixirDropsWeb.MCPJSON do
  @moduledoc false
  alias ElixirDrops.Drops.Drop

  @spec search(map()) :: map()
  def search(%{results: results}) do
    %{
      results: Enum.map(results.results, &drop_json/1),
      total: results.total,
      page: results.page,
      per_page: results.per_page
    }
  end

  defp drop_json(%Drop{} = drop) do
    %{
      id: drop.id,
      title: drop.title,
      excerpt: String.slice(drop.body || "", 0..150),
      author: drop.user.name,
      date: Calendar.strftime(drop.inserted_at, "%Y-%m-%d"),
      url: "https://elixirdrops.net/d/#{drop.short_id}"
    }
  end
end
