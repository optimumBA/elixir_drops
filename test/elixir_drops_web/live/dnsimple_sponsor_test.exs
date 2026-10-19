defmodule ElixirDropsWeb.DnsimpleSponsorTest do
  use ElixirDropsWeb.ConnCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Drops.Drop

  @card "#dnsimple-homepage-feed"

  setup do
    %{user: user_fixture()}
  end

  defp drops(user, count) do
    for n <- 1..count do
      drop_fixture(%Drop{}, user, %{title: "Organic drop #{String.pad_leading("#{n}", 2, "0")}"})
    end
  end

  defp card_count(html) do
    parts = String.split(html, ~s(id="dnsimple-homepage-feed"))
    length(parts) - 1
  end

  test "renders the exact labelled copy as the second feed entry", %{conn: conn, user: user} do
    drops(user, 3)
    {:ok, view, html} = live(conn, "/")

    assert card_count(html) == 1

    assert has_element?(
             view,
             @card <>
               "[href='https://blog.dnsimple.com/2026/10/making-dns-erlang-fast/?utm_source=elixirdrops&utm_medium=native&utm_campaign=dnsimple_q4_2026&utm_content=homepage-feed'][rel='sponsored noopener']"
           )

    assert has_element?(view, @card, "Sponsored")
    assert has_element?(view, @card, "DNSimple · Sponsor")
    assert has_element?(view, @card <> " img[src='/images/dnsimple-logomark-classic.svg']")
    assert has_element?(view, @card, "Making dns_erlang Fast: Binary Tricks for the BEAM")

    assert has_element?(
             view,
             @card,
             "Binary parsing and encoding patterns from DNSimple’s Erlang DNS library."
           )

    assert has_element?(view, @card, "Read the article")

    # Document order: organic newest, sponsor, then the rest.
    ids =
      ~r/id="(drop-[0-9a-f-]{36}|sponsor-dnsimple-homepage-feed)"/
      |> Regex.scan(html)
      |> Enum.map(&List.last/1)

    assert [_first, "sponsor-dnsimple-homepage-feed", _second | _] = ids
  end

  test "a single Drop still gets the card after it; zero Drops gets none", %{
    conn: conn,
    user: user
  } do
    {:ok, view, _html} = live(conn, "/")
    refute has_element?(view, @card)

    drops(user, 1)
    {:ok, view_with_drop, _html} = live(conn, "/")
    assert has_element?(view_with_drop, @card)
  end

  test "pagination and refresh never duplicate the card", %{conn: conn, user: user} do
    drops(user, 35)
    {:ok, view, html} = live(conn, "/")
    assert card_count(html) == 1

    assert card_count(render_hook(view, "load_more", %{})) == 1
    assert card_count(render_hook(view, "load_more", %{})) == 1
    assert card_count(render_hook(view, "refresh_drops", %{})) == 1
    assert card_count(render(view)) == 1

    # A fresh connection (reconnect) renders exactly one as well.
    {:ok, _view, fresh_html} = live(conn, "/")
    assert card_count(fresh_html) == 1
  end

  test "search, no-results and clearing search", %{conn: conn, user: user} do
    drops(user, 3)
    {:ok, view, _html} = live(conn, "/?q=Organic")
    refute has_element?(view, @card)

    {:ok, empty_view, empty_html} = live(conn, "/?q=zzzznotfound")
    refute has_element?(empty_view, @card)
    refute empty_html =~ "Sponsored · DNSimple"

    {:ok, home_view, _html} = live(conn, "/")
    assert has_element?(home_view, @card)
    render_patch(home_view, "/?q=Organic")
    refute has_element?(home_view, @card)

    # Clearing the search in the SAME LiveView restores organic Drops and
    # exactly one sponsor, second in order.
    html = render_patch(home_view, "/")
    assert card_count(html) == 1
    assert html =~ "Organic drop 01"
    assert html =~ "Organic drop 03"

    ids =
      ~r/id="(drop-[0-9a-f-]{36}|sponsor-dnsimple-homepage-feed)"/
      |> Regex.scan(html)
      |> Enum.map(&List.last/1)

    assert length(ids) == 4
    assert Enum.at(ids, 1) == "sponsor-dnsimple-homepage-feed"

    # The clear_search event takes the same path and also never duplicates.
    render_patch(home_view, "/?q=Organic")
    render_hook(home_view, "clear_search", %{})
    assert_patch(home_view, "/")
    assert card_count(render(home_view)) == 1
    assert card_count(render_hook(home_view, "refresh_drops", %{})) == 1
  end

  test "user pages never show the card", %{conn: conn, user: user} do
    drops(user, 3)
    {:ok, view, _html} = live(sign_in_user(conn, user), "/profile")
    refute has_element?(view, @card)
  end
end
