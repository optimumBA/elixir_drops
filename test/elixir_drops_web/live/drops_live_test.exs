defmodule ElixirDropsWeb.DropsLiveTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.DateTimeHelper
  alias ElixirDrops.Drops.Drop

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
      assert html =~ "Welcome to ElixirDrops"
    end

    test "shows the logged-in user's info", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)

      assert _user_token = get_session(conn, :user_token)

      {:ok, _live, html} = live(conn, ~p"/")

      assert html =~ "#{user.github_username}"
      assert html =~ "#{user.avatar}"
      assert html =~ "Welcome to ElixirDrops"
    end

    test "unauthorised users are cannot create drops", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      assert {:error, {:redirect, %{to: "#"}}} =
               live
               |> element("#create-post-button")
               |> render_click()
    end

    test "authorised users can navigate to create drops page", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)

      {:ok, live, _html} = live(conn, ~p"/")

      live
      |> element("#create-post-button")
      |> render_click()

      {path, _flash} = assert_redirect(live)

      assert path == ~p"/drop/new"
    end

    test "authorised users can navigate to edit a drop", %{conn: conn, user: user, drop: drop} do
      conn = sign_in_user(conn, user)

      {:ok, live, _html} = live(conn, ~p"/")

      assert {:error, {:redirect, %{to: path}}} =
               live
               |> element("#view-user-drops-link")
               |> render_click()

      assert path == ~p"/#{user.github_username}"

      {:ok, live_2, _html_2} = live(conn, path)

      live_2
      |> element("#edit-drop-#{drop.id}")
      |> render_click()

      {path, _flash} = assert_redirect(live_2)

      assert path == ~p"/drop/#{drop.id}/edit"
    end

    test "logged in user can navigate to view their drops", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)

      {:ok, live, _html} = live(conn, ~p"/")

      live
      |> element("#view-user-drops-link")
      |> render_click()

      {path, _flash} = assert_redirect(live)

      assert path == ~p"/#{user.github_username}"
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

  describe "/:username" do
    setup [:create_drops_setup]

    test "authorised users can view their their own drops", %{conn: conn, drop: drop, user: user} do
      user_2 =
        user_fixture(%{
          avatar: "https://avatars.githubusercontent.com/u/1456872?v=4",
          email: "user2@mail.com",
          github_id: 12_345,
          github_username: "user2_username",
          name: "user_2_name"
        })

      drop_2 = drop_fixture(%Drop{}, user_2, %{title: "Drop 2", body: "Body for drop 2"})

      conn = sign_in_user(conn, user)

      {:ok, _live, html} = live(conn, ~p"/#{user.github_username}")

      assert html =~ drop.title
      assert html =~ user.github_username
      refute html =~ drop_2.title
      refute html =~ user_2.github_username
    end

    test "unauthorised users are redirected", %{conn: conn, user: user} do
      assert {:error,
              {
                :redirect,
                %{to: path, flash: flash}
              }} =
               live(conn, ~p"/#{user.github_username}")

      assert flash["error"] == "You must log in to access this page."
      assert path == ~p"/"
    end
  end
end
