defmodule ElixirDropsWeb.DropLiveTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.DateTimeHelper
  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop

  defp create_drops_setup(%{conn: conn}) do
    conn =
      put_connect_params(
        conn,
        %{
          "show_welcome_message" => "true",
          "timezone_offset" => 0
        }
      )

    user = user_fixture()
    drop = drop_fixture(user)

    %{conn: conn, drop: drop, user: user}
  end

  describe "/" do
    setup [:create_drops_setup]

    test "shows github sign-in option for users not logged in", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/")

      assert html =~ "Sign in with GitHub"
      assert html =~ "Welcome to ElixirDrops"
    end

    test "shows the logged-in user's info", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)

      assert _user_token = get_session(conn, :user_token)

      {:ok, _live, html} = live(conn, ~p"/")

      assert html =~ "#{user.github_username}"
      assert html =~ "#{user.avatar}"
    end

    test "unauthorized users are cannot create drops", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      live
      |> element("#create-post-button")
      |> render_click()

      assert :ok = refute_redirected(live, ~p"/drops/new")
    end

    test "authorized users can navigate to create drops page", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)

      {:ok, live, _html} = live(conn, ~p"/")

      live
      |> element("#create-post-button")
      |> render_click()

      {path, _flash} = assert_redirect(live)

      assert path == ~p"/drops/new"
    end

    test "show a list of drops", %{conn: conn, drop: drop, user: user} do
      {:ok, _live, html} = live(conn, ~p"/")

      assert html =~ drop.title
      assert html =~ user.github_username
      assert html =~ user.avatar
      assert html =~ DateTimeHelper.convert_to_relative_time(drop.inserted_at, 0)
    end

    test "user can navigate to view a drop", %{conn: conn, drop: drop} do
      {:ok, live, _html} = live(conn, ~p"/")

      live
      |> element("#drop-#{drop.id}")
      |> render_click()

      {path, _flash} = assert_redirect(live)

      assert path == ~p"/drops/#{drop.id}"
    end

    test "gets updated with new drops", %{conn: conn, user: user} do
      {:ok, live, _html} = live(conn, ~p"/")

      refute has_element?(live, "#new-drops-indicator")

      {:ok, drop} =
        Drops.create_drop(%Drop{}, user, %{title: "New Drop title", body: "Drop body"})

      assert has_element?(live, "#new-drops-indicator")

      live
      |> element("#new-drops-indicator")
      |> render_click()

      assert has_element?(live, "#drop-#{drop.id}", drop.title)
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
