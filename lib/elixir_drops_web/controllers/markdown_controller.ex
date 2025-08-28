defmodule ElixirDropsWeb.MarkdownController do
  @moduledoc """
  Controller for serving markdown representations of drops.

  Handles `/d/:short_id.md` endpoints with proper Phoenix routing patterns.
  """

  use ElixirDropsWeb, :controller

  alias ElixirDrops.Drops
  alias ElixirDrops.MarkdownCache
  alias ElixirDrops.MarkdownFormatter

  @type conn :: Plug.Conn.t()
  @type params :: map()
  @type short_id :: String.t()

  @spec index(conn(), params()) :: conn()
  def index(conn, _params) do
    # Cache-first pattern: Check cache before hitting database
    case MarkdownCache.get_cached_index_content() do
      {:hit, cached_content} ->
        serve_markdown(conn, cached_content)

      :miss ->
        handle_cache_miss_for_index(conn)
    end
  end

  @spec show(conn(), params()) :: conn()
  def show(conn, %{"short_id" => short_id}) do
    # Cache-first pattern: Check cache before hitting database
    case MarkdownCache.get_cached_drop_content(short_id) do
      {:hit, cached_content} ->
        serve_markdown(conn, cached_content)

      :miss ->
        handle_cache_miss_for_drop(conn, short_id)
    end
  end

  # Private functions

  @spec serve_markdown(conn(), String.t()) :: conn()
  defp serve_markdown(conn, content) do
    conn
    |> put_resp_content_type("text/markdown")
    |> put_resp_header("cache-control", "public, max-age=300")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> text(content)
  end

  @spec handle_cache_miss_for_drop(conn(), short_id()) :: conn()
  defp handle_cache_miss_for_drop(conn, short_id) do
    case Drops.get_drop_by_short_id(short_id) do
      nil ->
        serve_not_found(conn)

      drop ->
        markdown_content =
          MarkdownCache.get_or_generate(:drop, drop, fn ->
            MarkdownFormatter.format_drop(drop)
          end)

        serve_markdown(conn, markdown_content)
    end
  end

  @spec handle_cache_miss_for_index(conn()) :: conn()
  defp handle_cache_miss_for_index(conn) do
    drops = Drops.list_all_drops()

    markdown_content =
      MarkdownCache.get_or_generate(:index, drops, fn ->
        MarkdownFormatter.format_index(drops)
      end)

    serve_markdown(conn, markdown_content)
  end

  @spec serve_not_found(conn()) :: conn()
  defp serve_not_found(conn) do
    conn
    |> put_resp_content_type("text/plain")
    |> put_status(404)
    |> text("# Drop Not Found\n\nThe requested drop does not exist or has been removed.")
  end
end
