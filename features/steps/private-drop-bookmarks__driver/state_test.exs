Code.require_file("support.exs", __DIR__)

defmodule PrivateDropBookmarks.StateTest do
  use ElixirDropsWeb.ConnCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Drops.Drop
  alias PrivateDropBookmarks.Support, as: S

  @alpha "BMK Alpha drop"
  @beta "BMK Beta drop"
  @mine "BMK Mine drop"

  defp home(conn) do
    {:ok, view, _} = live(conn, "/")
    {view, S.settle(view)}
  end

  defp bookmarks(conn) do
    {:ok, _, profile} = live(conn, "/profile")
    {:ok, view, _} = live(conn, S.bookmarks_href(profile))
    {view, S.settle(view)}
  end

  test "saving and removing agree across the homepage, Drop page, other lists, Bookmarks and sessions", %{conn: conn} do
    me = user_fixture(%{github_username: "zedbookmarker"})
    other = user_fixture(%{github_username: "quinnsecond"})
    author = user_fixture(%{github_username: "ainsleyauthor"})
    alpha = drop_fixture(%Drop{}, author, %{title: @alpha})
    _beta = drop_fixture(%Drop{}, author, %{title: @beta})
    _mine = drop_fixture(%Drop{}, me, %{title: @mine})
    me_conn = sign_in_user(conn, me)
    other_conn = sign_in_user(build_conn(), other)

    # Homepage: every card offers the control, in its three-dot menu, unsaved. Save Alpha.
    {home_view, html} = home(me_conn)
    assert S.card_state(html, @alpha) == "unsaved"
    assert S.card_state(html, @beta) == "unsaved"
    assert S.in_menu?(html, @alpha), "the homepage Bookmark control belongs in the card's three-dot menu"
    html = S.click_card(home_view, html, @alpha)
    assert S.card_state(html, @alpha) == "saved"
    assert S.card_state(html, @beta) == "unsaved"
    assert S.bookmark_count(html) == nil, "the homepage shows no aggregate count"

    # The Drop page shows it saved, in the action row (not in the three-dot menu), with a count of 1.
    {:ok, _page, page_html} = live(me_conn, "/d/#{alpha.short_id}")
    assert S.page_state(page_html) == "saved"
    assert S.buttons(Floki.find(S.doc(page_html), ".menu-panel")) == []
    assert S.bookmark_count(page_html) == 1

    # Another session of the same account finds it in Bookmarks and on the homepage after reload.
    {_, list} = bookmarks(sign_in_user(build_conn(), me))
    assert S.titles(list) == [@alpha]
    {_, html} = home(sign_in_user(build_conn(), me))
    assert S.card_state(html, @alpha) == "saved"

    # Other lists use the same control and show the same state: public profile Drops tab, My drops.
    {:ok, tab, _} = live(me_conn, "/u/#{author.id}/drops")
    tab_html = S.settle(tab)
    assert S.card_state(tab_html, @alpha) == "saved"
    assert S.card_state(tab_html, @beta) == "unsaved"
    {:ok, mine_view, _} = live(me_conn, "/profile")
    mine_html = S.settle(mine_view)
    assert S.card_state(mine_html, @mine) == "unsaved"
    mine_html = S.click_card(mine_view, mine_html, @mine)
    assert S.card_state(mine_html, @mine) == "saved"
    {_, html} = home(me_conn)
    assert S.card_state(html, @mine) == "saved"

    # Remove from the shared card on a profile tab: state and Bookmarks membership agree.
    tab_html = S.click_card(tab, tab_html, @alpha)
    assert S.card_state(tab_html, @alpha) == "unsaved"
    {_, list} = bookmarks(me_conn)
    assert S.titles(list) == [@mine]

    # Count reflects saves by different accounts and removals; nothing at zero.
    {:ok, other_page, other_html} = live(other_conn, "/d/#{alpha.short_id}")
    assert S.bookmark_count(other_html) == nil
    assert S.page_state(other_html) == "unsaved"
    S.click_page(other_page, other_html)
    {:ok, page, page_html} = live(me_conn, "/d/#{alpha.short_id}")
    S.click_page(page, page_html)
    {:ok, _, guest_html} = live(build_conn(), "/d/#{alpha.short_id}")
    assert S.bookmark_count(guest_html) == 2
    assert S.page_state(guest_html) == "unsaved"
    {:ok, page, page_html} = live(me_conn, "/d/#{alpha.short_id}")
    assert S.page_state(page_html) == "saved"
    html = S.click_page(page, page_html)
    assert S.page_state(html) == "unsaved"
    {:ok, other_page, other_html} = live(other_conn, "/d/#{alpha.short_id}")
    assert S.bookmark_count(other_html) == 1
    S.click_page(other_page, other_html)
    {:ok, _, guest_html} = live(build_conn(), "/d/#{alpha.short_id}")
    assert S.bookmark_count(guest_html) == nil

    # Remove from Bookmarks itself: the card leaves the list and the homepage agrees.
    {list_view, list} = bookmarks(me_conn)
    assert S.titles(list) == [@mine]
    list = S.click_card(list_view, list, @mine)
    assert S.titles(list) == []
    {_, list} = bookmarks(me_conn)
    assert S.titles(list) == []
    {_, html} = home(me_conn)
    assert S.card_state(html, @mine) == "unsaved"
  end
end
