defmodule ElixirDropsWeb.DropsLiveTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDropsWeb.DropsLiveHelpers

  defp create_drops_setup(%{conn: conn}) do
    conn = put_connect_params(conn, %{"timezone_offset" => 0})
    user = user_fixture()
    drop = drop_fixture(user)

    %{conn: conn, drop: drop, user: user}
  end

  describe "/" do
    setup [:create_drops_setup]

    test "lists all drops", %{conn: conn, drop: drop, user: user} do
      {:ok, _live, html} = live(conn, ~p"/")

      assert html =~ drop.title
      assert html =~ user.github_username
      assert html =~ user.avatar
      assert html =~ DropsLiveHelpers.convert_time(drop.inserted_at, 0)
    end

    test "user navigates to the drop", %{conn: conn, drop: drop} do
      {:ok, live, _html} = live(conn, ~p"/")

      live
      |> element("#drop-#{drop.id}")
      |> render_click()

      assert_patch(live, ~p"/drops/#{drop.id}")
      assert has_element?(live, "#drop-body")
    end
  end

  describe "/drops/:id" do
    setup [:create_drops_setup]

    test "user can view a drop", %{conn: conn, drop: drop, user: user} do
      {:ok, _live, html} = live(conn, ~p"/drops/#{drop.id}")

      assert html =~ ~r(<p>Drop body text...</p>)
      assert html =~ drop.title
      assert html =~ user.github_username
      assert html =~ user.avatar
      assert html =~ DropsLiveHelpers.convert_time(drop.inserted_at, 0)
    end

    test "user redirected to home page when drop does not exist", %{conn: conn} do
      drop_id = Ecto.UUID.generate()
      path = "/"

      assert {:error, {:live_redirect, %{to: ^path}}} =
               live(conn, ~p"/drops/#{drop_id}")
    end
  end
end
