defmodule ElixirDrops.Sitemap do
  @moduledoc """
  Handles sitemap generation for ElixirDrops.
  """

  use ElixirDropsWeb, :verified_routes

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop

  @doc """
  Regenerates the sitemap from the current public collection.

  Rebuilding keeps new, edited, and removed drops in the same newest-first
  order and prevents a publication from being appended after older entries.
  Returns {:ok, path} on success or {:error, reason} on failure.
  """
  @spec generate(Drop.t()) :: {:ok, String.t()} | {:error, String.t()}
  def generate(%Drop{}), do: generate_full()

  @doc """
  Generates a full sitemap with all drops.
  Returns {:ok, path} on success or {:error, reason} on failure.
  """
  @spec generate_full() :: {:ok, String.t()} | {:error, String.t()}
  def generate_full do
    sitemap_dir = Path.join([:code.priv_dir(:elixir_drops), "static"])

    case File.mkdir_p(sitemap_dir) do
      :ok ->
        sitemap_path = Path.join([sitemap_dir, "sitemap.xml"])

        :global.trans({{__MODULE__, sitemap_path}, self()}, fn ->
          generate_full_sitemap(sitemap_path)
        end)

      {:error, reason} ->
        {:error, "Failed to create sitemap directory: #{inspect(reason)}"}
    end
  end

  defp generate_full_sitemap(sitemap_path) do
    drops = Drops.list_all_drops()
    sitemap_content = generate_sitemap_content(drops)

    case atomic_write(sitemap_path, sitemap_content) do
      :ok ->
        {:ok, sitemap_path}

      {:error, reason} ->
        {:error, "Failed to write sitemap file: #{inspect(reason)}"}
    end
  end

  defp atomic_write(path, content) do
    temp_path = path <> ".#{System.unique_integer([:positive, :monotonic])}.tmp"

    try do
      case File.write(temp_path, content, [:binary, :exclusive]) do
        :ok -> File.rename(temp_path, path)
        {:error, reason} -> {:error, reason}
      end
    after
      File.rm(temp_path)
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
    <url>
      <loc>#{escape_xml(url(~p"/archive"))}</loc>
      <changefreq>weekly</changefreq>
      <priority>0.9</priority>
    </url>
    #{drops_elements(drops)}
    </urlset>
    """
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
