defmodule ElixirDropsWeb.DropsLiveTest do
  use ElixirDropsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import ElixirDrops.AccountsFixtures

  alias ElixirDrops.Accounts

  describe "/" do
    test "logged in user navigation details", %{conn: conn} do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      conn = init_test_session(conn, %{user_token: token})

      assert _user_token = get_session(conn, :user_token)

      {:ok, _live, html} = live(conn, ~p"/")

      assert html =~ "#{user.github_username}"
      assert html =~ "#{user.avatar}"
    end
  end
end
