defmodule ElixirDropsWeb.DropLiveShowTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.BookmarksFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Drops.Drop

  defp create_drop_setup(%{conn: conn}) do
    user = user_fixture()
    drop = drop_fixture(%Drop{}, user)
    conn = sign_in_user(conn, user)

    %{conn: conn, drop: drop, user: user}
  end

  describe "/d/short_id" do
    setup [:create_drop_setup]

    test "a user who has logged in can bookmark a drop", %{conn: conn, drop: drop} do
      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      assert view
             |> element("#bookmark-button-#{drop.id}", "Bookmark Drop")
             |> render_click() =~ "Remove Bookmark"
    end

    test "a user who has logged in can unbookmark a drop", %{conn: conn, drop: drop, user: user} do
      _bookmark = bookmark_fixture(%{drop_id: drop.id, user_id: user.id})

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      assert view
             |> element("#remove-bookmark-button-#{drop.id}", "Remove Bookmark")
             |> render_click() =~ "Bookmark Drop"
    end

    test "a user who has not logged in can neither bookmark nor unbookmark a drop", %{drop: drop} do
      conn = build_conn()
      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      refute view
             |> element("#bookmark-button-#{drop.id}", "Bookmark Drop")
             |> has_element?()

      refute view
             |> element("#remove-bookmark-button-#{drop.id}", "Remove Bookmark")
             |> has_element?()
    end
  end
end
