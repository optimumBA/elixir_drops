Code.require_file("support.exs", __DIR__)

defmodule PrivateDropBookmarks.PrivacyTest do
  use ElixirDropsWeb.ConnCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Drops.Drop
  alias PrivateDropBookmarks.Support, as: S

  @secret "PRV Secret drop"

  test "bookmark lists and bookmarkers stay private and the count shows only on the Drop page", %{conn: conn} do
    saver = user_fixture(%{github_username: "zedsaver", name: "Zed Saver"})
    snoop = user_fixture(%{github_username: "snoopsnoop"})
    author = user_fixture(%{github_username: "ainsleyauthor"})
    drop = drop_fixture(%Drop{}, author, %{title: @secret})
    saver_conn = sign_in_user(conn, saver)

    {:ok, page, html} = live(saver_conn, "/d/#{drop.short_id}")
    S.click_page(page, html)
    {:ok, _, profile} = live(saver_conn, "/profile")
    href = S.bookmarks_href(profile)
    {:ok, view, _} = live(saver_conn, href)
    assert S.titles(S.settle(view)) == [@secret]

    # Another account at the same address sees only its own (empty) list.
    {:ok, other_view, _} = live(sign_in_user(build_conn(), snoop), href)
    other = S.settle(other_view)
    assert S.titles(other) == []
    refute S.page_text(other) =~ @secret

    # A signed-out visitor cannot open it and learns nothing of it.
    assert {:error, {kind, _}} = live(build_conn(), href)
    assert kind in [:redirect, :live_redirect]

    # The public profile of the saver exposes no bookmarks and no Bookmarks link.
    for path <- ["/u/#{saver.id}", "/u/#{saver.id}/drops", "/u/#{saver.id}/comments"] do
      {:ok, v, first} = live(build_conn(), path)
      shown = first <> S.settle(v)
      refute shown =~ @secret, "#{path} exposes a bookmarked Drop"
      refute S.page_text(shown) =~ ~r/bookmarks/i, "#{path} mentions bookmarks"
    end

    # Drop page for guests, other accounts and the author: count only, no identity.
    for conn <- [build_conn(), sign_in_user(build_conn(), snoop), sign_in_user(build_conn(), author)] do
      {:ok, _, shown} = live(conn, "/d/#{drop.short_id}")
      assert S.bookmark_count(shown) == 1
      refute shown =~ "zedsaver"
      refute shown =~ "Zed Saver"
      refute shown =~ to_string(saver.id)
    end

    # The count appears on no list: homepage, author profile Drops tab, author's My drops.
    {:ok, home, _} = live(build_conn(), "/")
    assert S.bookmark_count(S.settle(home)) == nil
    {:ok, tab, _} = live(build_conn(), "/u/#{author.id}/drops")
    assert S.bookmark_count(S.settle(tab)) == nil
    {:ok, mine, _} = live(sign_in_user(build_conn(), author), "/profile")
    mine_html = S.settle(mine)
    assert S.titles(mine_html) == [@secret]
    assert S.bookmark_count(mine_html) == nil
    refute mine_html =~ "zedsaver"
  end
end
