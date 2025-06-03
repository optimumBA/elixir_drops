defmodule ElixirDrops.Sitemap do
  @moduledoc """
  Handles sitemap generation for ElixirDrops.
  """

  use ElixirDropsWeb, :verified_routes

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop

  @doc """
  Generates or updates the sitemap.
  When called with a drop, it updates the sitemap with that drop.
  When called without arguments, it generates a new sitemap with all drops.
  Returns {:ok, path} on success or {:error, reason} on failure.
  """
  @spec generate(Drop.t()) :: {:ok, String.t()} | {:error, String.t()}
  def generate(drop) do
    with sitemap_dir <- Path.join([:code.priv_dir(:elixir_drops), "static"]),
         :ok <- File.mkdir_p(sitemap_dir),
         sitemap_path <- Path.join([sitemap_dir, "sitemap.xml"]) do
      case {drop, File.exists?(sitemap_path)} do
        {_drop, false} ->
          generate_full_sitemap(sitemap_path)

        {drop, true} ->
          update_sitemap_with_drop(drop, sitemap_path)
      end
    end
  end

  defp generate_full_sitemap(sitemap_path) do
    drops = Drops.list_drops(%{}, 10_000)
    sitemap_content = generate_sitemap_content(drops)

    case File.write(sitemap_path, sitemap_content) do
      :ok ->
        {:ok, sitemap_path}

      {:error, reason} ->
        {:error, "Failed to write sitemap file: #{inspect(reason)}"}
    end
  end

  defp update_sitemap_with_drop(drop, sitemap_path) do
    with {:ok, content} <- File.read(sitemap_path),
         updated_content <- update_sitemap_content(content, drop),
         :ok <- File.write(sitemap_path, updated_content) do
      {:ok, sitemap_path}
    else
      {:error, reason} ->
        {:error, "Failed to update sitemap file: #{inspect(reason)}"}
    end
  end

  defp generate_sitemap_content(drops) do
    """
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
  end

  defp drops_elements(drops) do
    Enum.map_join(drops, "\n", &drop_element/1)
  end

  defp drop_element(%Drop{short_id: short_id, updated_at: updated_at, title: title}) do
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
      <title>#{escape_xml(title)}</title>
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

  defp update_sitemap_content(content, drop) do
    drop_element = drop_element(drop)
    drop_url = url(~p"/d/#{drop.short_id}")

    if String.contains?(content, drop_url) do
      pattern = ~r(<url>\s*<loc>#{Regex.escape(drop_url)}</loc>.*?</url>)s
      String.replace(content, pattern, drop_element)
    else
      String.replace(content, "</urlset>", "#{drop_element}\n</urlset>")
    end
  end
end
