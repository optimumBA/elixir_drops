Code.require_file("support.exs", __DIR__)

defmodule PrivateDropBookmarks.BoundTest do
  use ElixirDropsWeb.ConnCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Drops.Drop
  alias PrivateDropBookmarks.Support, as: S

  # Bookmarks are created through the real Drop-page control; the measured work is opening the
  # homepage (cards with saved state), opening Bookmarks and every further batch.
  defp measure(conn, size) do
    me = user_fixture(%{github_username: "bound#{size}user"})
    author = user_fixture(%{github_username: "bound#{size}author"})
    me_conn = sign_in_user(conn, me)

    for i <- 1..size do
      drop = drop_fixture(%Drop{}, author, %{title: "BMB #{size} #{S.pad(i)} drop"})
      {:ok, page, html} = live(me_conn, "/d/#{drop.short_id}")
      S.click_page(page, html)
    end

    {_, home} =
      S.count(fn ->
        {:ok, v, _} = live(me_conn, "/")
        S.settle(v)
      end)

    {:ok, _, profile} = live(me_conn, "/profile")
    href = S.bookmarks_href(profile)

    {view, open} =
      S.count(fn ->
        {:ok, v, _} = live(me_conn, href)
        S.settle(v)
        v
      end)

    %{home: home, open: open, batches: batches(view, length(S.titles(render(view))), size, [])}
  end

  # Every continuation batch until the list stops growing: {queries, entries added}.
  defp batches(view, loaded, size, acc) do
    {html, n} =
      S.count(fn ->
        render_hook(view, "load_more", %{})
        S.settle(view)
      end)

    now = length(S.titles(html))

    if now > loaded and length(acc) < size,
      do: batches(view, now, size, [{n, now - loaded} | acc]),
      else: Enum.reverse(acc)
  end

  # A small account and one with three times as many bookmarks.
  test "query count stays within the same bound for a small and a large number of bookmarks", %{conn: conn} do
    small = measure(conn, 15)
    large = measure(conn, 45)

    assert small.batches != [], "small list loaded no continuation batch"
    assert length(large.batches) >= 2, "large list stopped loading: #{inspect(large.batches)}"
    small_bound = small.batches |> Enum.map(&elem(&1, 0)) |> Enum.max()
    assert large.home <= small.home, "homepage: #{large.home} queries with the large account vs #{small.home} with the small"
    assert large.open <= small.open, "opening Bookmarks: #{large.open} queries for the large account vs #{small.open} for the small"

    assert Enum.all?(large.batches, fn {q, _added} -> q <= small_bound end),
           "batches for the large account: #{inspect(large.batches)}; bound from the small account: #{small_bound}"

    assert Enum.all?(large.batches ++ small.batches, fn {q, added} -> q < added end),
           "a batch costs one query per entry: #{inspect(large.batches ++ small.batches)}"
  end
end
