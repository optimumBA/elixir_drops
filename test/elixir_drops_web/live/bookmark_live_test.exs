defmodule ElixirDropsWeb.BookmarkLiveTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Bookmarks
  alias ElixirDrops.Drops.Drop

  setup %{conn: conn} do
    user = user_fixture(%{github_username: "bookmark_viewer"})
    author = user_fixture(%{github_username: "bookmark_author"})
    drop = drop_fixture(%Drop{}, author, %{title: "Shared control drop"})
    %{author: author, conn: sign_in_user(conn, user), drop: drop, user: user}
  end

  defp click(view, selector) do
    element = element(view, selector)
    render_click(element)
  end

  defp markup(view, selector) do
    element = element(view, selector)
    render(element)
  end

  test "the Drop page control saves and removes and shows the public count", %{
    conn: conn,
    drop: drop
  } do
    {:ok, view, html} = live(conn, ~p"/d/#{drop.short_id}")
    button = "#single-drop-bookmark-#{drop.id}"

    assert html =~ ~s(aria-pressed="false")
    refute has_element?(view, "#drop-bookmark-count")

    click(view, button)
    assert has_element?(view, "#{button}[aria-pressed='true']")
    assert markup(view, "#drop-bookmark-count") =~ "1 bookmark"

    click(view, button)
    assert has_element?(view, "#{button}[aria-pressed='false']")
    refute has_element?(view, "#drop-bookmark-count")
  end

  test "the card menu control toggles the card in place", %{conn: conn, drop: drop} do
    {:ok, view, _html} = live(conn, ~p"/")
    button = "#card-bookmark-#{drop.id}"

    assert has_element?(view, "#drop-card-menu-#{drop.id} #{button}[aria-pressed='false']")
    click(view, button)
    assert has_element?(view, "#{button}[aria-pressed='true']")
    refute render(view) =~ ~r/\d+\s+bookmarks?\b/
  end

  test "a visitor sees an unsaved control that opens the sign-in dialog and saves nothing", %{
    drop: drop
  } do
    {:ok, view, _html} = live(build_conn(), ~p"/")
    button = "#card-bookmark-#{drop.id}"

    assert has_element?(view, "#{button}[aria-pressed='false']")
    assert markup(view, button) =~ "signin-popup-message"
    assert has_element?(view, "#signin-popup-message")

    # Even a forged event from a visitor changes nothing.
    render_hook(view, "toggle_bookmark", %{"drop_id" => drop.id, "saved" => true})
    assert Bookmarks.count_drop_bookmarks(drop.id) == 0
  end

  test "malformed or unknown events change nothing", %{conn: conn, drop: drop} do
    {:ok, view, _html} = live(conn, ~p"/")

    render_hook(view, "toggle_bookmark", %{"drop_id" => "nope", "saved" => true})
    render_hook(view, "toggle_bookmark", %{"drop_id" => Ecto.UUID.generate(), "saved" => true})
    render_hook(view, "toggle_bookmark", %{"drop_id" => drop.id})

    assert Bookmarks.count_drop_bookmarks(drop.id) == 0
  end

  test "the Bookmarks page is for signed-in accounts and lists only their own", %{
    conn: conn,
    drop: drop,
    user: user
  } do
    assert {:error, {:redirect, _redirect}} = live(build_conn(), ~p"/bookmarks")

    {:ok, view, html} = live(conn, ~p"/bookmarks")
    assert html =~ "No bookmarks yet"
    refute has_element?(view, ".drop-card")

    :ok = Bookmarks.save_bookmark(user.id, drop.id)
    {:ok, saved_view, saved_html} = live(conn, ~p"/bookmarks")
    refute saved_html =~ "No bookmarks yet"
    assert has_element?(saved_view, "#drop-#{drop.id} .drop-card")

    click(saved_view, "#card-bookmark-#{drop.id}")
    refute has_element?(saved_view, ".drop-card")
    assert render(saved_view) =~ "No bookmarks yet"
    refute Bookmarks.bookmarked?(user.id, drop.id)

    {:ok, other_view, other_html} =
      live(sign_in_user(build_conn(), user_fixture()), ~p"/bookmarks")

    assert other_html =~ "No bookmarks yet"
    refute has_element?(other_view, ".drop-card")
  end

  test "the account menu and My drops header link Bookmarks after My drops", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/profile")

    assert has_element?(view, "#slide-menu a#view-bookmarks-link[href='/bookmarks']", "Bookmarks")
    assert has_element?(view, "#secondary-nav-links a[href='/bookmarks']", "Bookmarks")
  end
end
