defmodule ElixirDropsWeb.DropsLiveTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Accounts
  alias ElixirDrops.DateTimeHelper

  defp create_drops_setup(%{conn: conn}) do
    conn = put_connect_params(conn, %{"timezone_offset" => 0})
    user = user_fixture()
    drop = drop_fixture(user)

    %{conn: conn, drop: drop, user: user}
  end

  describe "/" do
    setup [:create_drops_setup]

    test "shows github sign-in option for users not logged in", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/")

      assert html =~ "Sign in with GitHub"
    end

    test "shows the logged-in user's info", %{conn: conn} do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      conn = init_test_session(conn, %{user_token: token})

      assert _user_token = get_session(conn, :user_token)

      {:ok, _live, html} = live(conn, ~p"/")

      assert html =~ "#{user.github_username}"
      assert html =~ "#{user.avatar}"
    end

    test "lists all drops", %{conn: conn, drop: drop, user: user} do
      {:ok, _live, html} = live(conn, ~p"/")

      assert html =~ drop.title
      assert html =~ user.github_username
      assert html =~ user.avatar
      assert html =~ DateTimeHelper.convert_to_relative_time(drop.inserted_at, 0)
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
      assert html =~ DateTimeHelper.convert_to_relative_time(drop.inserted_at, 0)
    end

    test "user redirected to home page when drop does not exist", %{conn: conn} do
      drop_id = Ecto.UUID.generate()
      path = "/"

      assert {:error, {:live_redirect, %{to: ^path}}} =
               live(conn, ~p"/drops/#{drop_id}")
    end
  end
end
