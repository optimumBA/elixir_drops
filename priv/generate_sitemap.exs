defmodule SitemapGenerator do
  use ElixirDropsWeb, :verified_routes

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop

  def generate do
    drops = Drops.list_drops(%{}, 10_000)

    sitemap_content = """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    <url>
      <loc>#{escape_xml(url(~p"/"))}</loc>
      <changefreq>daily</changefreq>
      <priority>1.0</priority>
    </url>
    #{drops_elements(drops)}
    </urlset>
    """

    priv_dir =
      :elixir_drops
      |> :code.priv_dir()
      |> to_string()

    sitemap_path = Path.join([priv_dir, "static", "sitemap.xml"])
    File.write!(sitemap_path, sitemap_content)

    IO.puts("Sitemap generated at #{sitemap_path} with #{length(drops)} drops.")
  end

  defp drops_elements(drops) do
    Enum.map_join(drops, "\n", &drop_element/1)
  end

  defp drop_element(%Drop{short_id: short_id, updated_at: updated_at}) do
    last_modified =
      updated_at
      |> NaiveDateTime.to_date()
      |> Date.to_iso8601()

    """
    <url>
      <loc>#{escape_xml(url(~p"/d/#{short_id}"))}</loc>
      <lastmod>#{last_modified}</lastmod>
      <changefreq>monthly</changefreq>
      <priority>0.8</priority>
    </url>
    """
  end

  defp escape_xml(string) do
    string
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end

{:ok, _} = Application.ensure_all_started(:elixir_drops)
SitemapGenerator.generate()
