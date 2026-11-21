defmodule CrawlableArchiveEntry20261121.ArchiveReachTest do
  use ElixirDropsWeb.ConnCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Drops.Drop

  defp anchors(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("a")
    |> Enum.map(fn a ->
      {a |> Floki.text(sep: " ") |> String.split() |> Enum.join(" "),
       List.first(Floki.attribute(a, "href"))}
    end)
  end

  test "homepage archive link reaches an older Drop article and existing routes keep working", %{
    conn: conn
  } do
    user = user_fixture()

    drops =
      for n <- 1..20 do
        drop = drop_fixture(%Drop{}, user, %{title: "Reach drop #{n}"})
        update_drop_inserted_at(drop, -n * 60)
      end

    oldest = List.last(drops)
    newest = hd(drops)

    # Initial homepage render: first batch only, so the oldest Drop is not linked there.
    {:ok, _view, home_html} = live(conn, ~p"/")
    assert home_html =~ newest.title, "fixture: newest Drop missing from the homepage"
    refute home_html =~ oldest.title, "fixture: oldest Drop is in the homepage first batch"

    # Infinite scroll is preserved.
    assert home_html =~ ~s(id="infinite-scroll-marker")
    assert home_html =~ ~s(phx-hook="InfiniteScroll")

    # Follow the homepage link, as a crawler would, with plain HTTP.
    href =
      case Enum.filter(anchors(home_html), fn {text, _} -> text == "Browse all Drops" end) do
        [{_text, href}] when is_binary(href) -> href
        other -> flunk("expected one Browse all Drops link on the homepage, got #{inspect(other)}")
      end

    assert URI.parse(href).path == "/archive"
    archive_html = html_response(get(conn, href), 200)
    archive_links = anchors(archive_html)

    for drop <- drops do
      assert {drop.title, "/d/#{drop.short_id}"} in archive_links,
             "archive does not link #{drop.title}"
    end

    # The older article's URL still serves its article.
    article_html = html_response(get(conn, ~p"/d/#{oldest.short_id}"), 200)
    assert article_html =~ oldest.title
  end
end
