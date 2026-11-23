Code.require_file("support.exs", __DIR__)

defmodule PrivateDropBookmarks.ListTest do
  use ElixirDropsWeb.ConnCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Drops.Drop
  alias PrivateDropBookmarks.Support, as: S

  defp title(i), do: "BML #{S.pad(i)} drop"

  defp save(conn, drop) do
    {:ok, page, html} = live(conn, "/d/#{drop.short_id}")
    assert S.page_state(html) == "unsaved"
    html = S.click_page(page, html)
    assert S.page_state(html) == "saved"
    Process.sleep(25)
  end

  defp unsave(conn, drop) do
    {:ok, page, html} = live(conn, "/d/#{drop.short_id}")
    assert S.page_state(html) == "saved"
    S.click_page(page, html)
    Process.sleep(25)
  end

  defp open(conn) do
    {:ok, _, profile} = live(conn, "/profile")
    {:ok, view, _} = live(conn, S.bookmarks_href(profile))
    {view, S.settle(view)}
  end

  defp load_all(view, html, total, tries \\ 12) do
    if length(S.titles(html)) >= total or tries == 0 do
      html
    else
      render_hook(view, "load_more", %{})
      load_all(view, S.settle(view), total, tries - 1)
    end
  end

  test "bookmarks list shows latest saved first, loads on scroll and shows an empty state", %{conn: conn} do
    me = user_fixture(%{github_username: "listbookmarker"})
    author = user_fixture(%{github_username: "listauthor"})
    drops = for i <- 1..25, do: {i, drop_fixture(%Drop{}, author, %{title: title(i)})}
    by_index = Map.new(drops)
    me_conn = sign_in_user(conn, me)

    # Empty state before anything is saved.
    {_, empty} = open(me_conn)
    assert S.titles(empty) == []
    assert S.page_text(empty) =~ ~r/no bookmarks yet/i

    # Save order differs from creation order: 7, 14, 21, ... modulo 25.
    saves = Enum.map(1..25, fn k -> rem(k * 7, 25) + 1 end)
    for i <- saves, do: save(me_conn, by_index[i])
    expected = saves |> Enum.reverse() |> Enum.map(&title/1)

    # First load is a partial batch; scrolling loads the rest, newest saved first, each once.
    {view, first} = open(me_conn)
    shown = length(S.titles(first))
    assert shown >= 1 and shown < 25, "the first load must be a partial batch, got #{shown} of 25"
    assert S.titles(first) == Enum.take(expected, shown)
    assert S.bookmark_count(first) == nil, "the list shows no aggregate count"
    all = load_all(view, first, 25)
    assert S.titles(all) == expected

    # Removing and saving again moves a Drop to the top.
    unsave(me_conn, by_index[hd(saves)])
    save(me_conn, by_index[hd(saves)])
    {view, again} = open(me_conn)
    assert hd(S.titles(again)) == title(hd(saves))
    again = load_all(view, again, 25)
    assert S.titles(again) == [title(hd(saves)) | List.delete(expected, title(hd(saves)))]

    # Remove every Drop from the list itself: the empty state returns.
    {view, html} = open(me_conn)
    html = remove_all(view, html, 60)
    assert S.titles(html) == []
    assert S.page_text(html) =~ ~r/no bookmarks yet/i
    {_, reloaded} = open(me_conn)
    assert S.titles(reloaded) == []
  end

  defp remove_all(view, html, guard) when guard > 0 do
    case S.titles(html) do
      [first | _] ->
        remove_all(view, S.click_card(view, html, first), guard - 1)

      [] ->
        render_hook(view, "load_more", %{})
        next = S.settle(view)
        if S.titles(next) == [], do: next, else: remove_all(view, next, guard - 1)
    end
  end

  defp remove_all(_view, html, _guard), do: html
end
