defmodule ElixirDropsWeb.CommentsAuthRedirectTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  describe "authentication redirect for comments" do
    test "sign in link includes return URL parameter", %{conn: conn} do
      user = user_fixture()
      drop = drop_fixture(%ElixirDrops.Drops.Drop{}, user)

      {:ok, _view, html} = live(conn, ~p"/d/#{drop.short_id}")

      # Check that the sign in link includes the return_to parameter
      assert html =~ ~r{/auth/github\?return_to=/d/#{drop.short_id}}
    end

    test "user is redirected to drop page after sign in", %{conn: conn} do
      user = user_fixture()
      drop = drop_fixture(%ElixirDrops.Drops.Drop{}, user)

      # Set the return URL in session
      conn_with_session =
        conn
        |> init_test_session(%{})
        |> put_session(:user_return_to, ~p"/d/#{drop.short_id}")

      # Simulate successful authentication
      authenticated_conn = ElixirDropsWeb.UserAuth.log_in_user(conn_with_session, user)

      # Check that user is redirected to the drop page
      assert redirected_to(authenticated_conn, 302) == ~p"/d/#{drop.short_id}"
    end

    test "user is redirected to home page if no return URL", %{conn: conn} do
      user = user_fixture()

      # Simulate successful authentication without return URL
      conn_with_session = init_test_session(conn, %{})

      authenticated_conn = ElixirDropsWeb.UserAuth.log_in_user(conn_with_session, user)

      # Check that user is redirected to home page
      assert redirected_to(authenticated_conn, 302) == ~p"/"
    end
  end
end
