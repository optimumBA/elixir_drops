defmodule ElixirDropsWeb.DropLiveTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.DateTimeHelper
  alias ElixirDrops.Drops
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

    test "authorized users can navigate to edit a drop", %{conn: conn, user: user, drop: drop} do
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

      assert path == ~p"/drops/#{drop.unique_url_string}/edit"
    end

    test "authorized users can view their drops", %{conn: conn, drop: drop, user: user} do
      conn = sign_in_user(conn, user)

      {:ok, live, _html} = live(conn, ~p"/")

      assert {:ok, conn} =
               live
               |> element("#view-user-drops-link")
               |> render_click()
               |> follow_redirect(conn, ~p"/#{user.github_username}")

      html = html_response(conn, 200)

      assert html =~ "My posts"
      assert html =~ drop.title
      assert html =~ user.avatar
      assert html =~ user.github_username
      assert html =~ DateTimeHelper.convert_to_relative_time(drop.inserted_at, 0)
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

      assert_patch(live, ~p"/drops/#{drop.unique_url_string}")
    end

    test "can see older drops with infinite scroll", %{conn: conn, user: user} do
      for drop <- 1..25 do
        time = 120 * drop

        %Drop{}
        |> drop_fixture(user, %{title: "Drop title #{drop}", body: "Body for drop #{drop}"})
        |> update_drop_inserted_at(time)
      end

      {:ok, live, _html} = live(conn, ~p"/")

      assert html_2 = render_hook(live, "next-page", %{})

      assert html_2 =~ "Drop title 11"
      assert html_2 =~ "Drop title 14"
    end

    test "can see newer drops with infinite scroll", %{conn: conn, user: user} do
      for drop <- 1..25 do
        time = 120 * drop

        %Drop{}
        |> drop_fixture(user, %{title: "Drop title #{drop}", body: "Body for drop #{drop}"})
        |> update_drop_inserted_at(time)
      end

      {:ok, live, _html} = live(conn, ~p"/")

      assert html_2 = render_hook(live, "prev-page", %{})

      assert html_2 =~ "Drop title 1"
      refute html_2 =~ "Drop title 14"
    end
  end

  describe "/drops/:id" do
    setup [:create_drops_setup]

    test "user can view a drop", %{conn: conn, drop: drop, user: user} do
      {:ok, _live, html} = live(conn, ~p"/drops/#{drop.unique_url_string}")

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

    test "authorized users can view their their own drops", %{conn: conn, drop: drop, user: user} do
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

    test "unauthorized users are redirected", %{conn: conn, user: user} do
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

  describe "/drop/new" do
    setup [:create_drops_setup]

    test "authorized users can create drops", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)

      {:ok, live, _html} = live(conn, ~p"/drops/new")

      {:ok, _live, html} =
        live
        |> form("#drops-editor-form", drop: %{title: "New Drop title", body: "Drop body"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/#{user.github_username}")

      assert html =~ "New Drop title"
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

    test "authorized users cannot create a drop with invalid data", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)

      {:ok, live, _html} = live(conn, ~p"/drops/new")

      live
      |> form("#drops-editor-form", drop: %{title: "", body: ""})
      |> render_change() =~ "can&#39;t be blank"
    end

    test "unauthorized users are redirected", %{conn: conn} do
      assert {:error, {:redirect, %{to: path, flash: flash}}} = live(conn, ~p"/drops/new")

      assert path == ~p"/"
      assert flash["error"] == "You must log in to access this page."
    end

    test "parses Markdown in drop body and renders it in the Preview section", %{
      conn: conn,
      user: user
    } do
      conn = sign_in_user(conn, user)

      {:ok, live, _html} = live(conn, ~p"/drops/new")

      drop_body = """
      # Test heading

      ## Test subheading

      Some *text* here

      * Some list item
      * Another list item
      """

      html =
        live
        |> form("#drops-editor-form", drop: %{title: "Drop title here", body: drop_body})
        |> render_change()

      assert html =~ "Drop title here"
      assert html =~ ~r|<h1>Test heading</h1|
      assert html =~ ~r|<h2>Test subheading</h2|
      assert html =~ ~r|<p>Some <em>text<\/em> here|

      assert html =~
               ~r|<ul><li>Some list item</li><li>Another list item</li></ul>|
    end
  end

  describe "/drops/:id/edit" do
    setup [:create_drops_setup]

    test "authorized user updates a drop", %{conn: conn, user: user, drop: drop} do
      conn = sign_in_user(conn, user)

      {:ok, live, html} = live(conn, ~p"/drops/#{drop.unique_url_string}/edit")

      assert html =~ "Edit post"
      assert html =~ drop.body
      assert html =~ drop.title

      {:ok, _live, updated_html} =
        live
        |> form("#drops-editor-form", drop: %{title: "New Drop title", body: "New Drop body"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/#{user.github_username}")

      assert updated_html =~ "New Drop title"

      assert updated_drop = Drops.get_drop(drop.id)
      assert updated_drop.title == "New Drop title"
      assert updated_drop.body == "New Drop body"
    end

    test "authorized user cannot update a drop with invalid data", %{
      conn: conn,
      drop: drop,
      user: user
    } do
      conn = sign_in_user(conn, user)

      {:ok, live, _html} = live(conn, ~p"/drops/#{drop.unique_url_string}/edit")

      html =
        live
        |> form("#drops-editor-form", drop: %{title: "", body: "New Drop body"})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "unauthorized users are redirected", %{conn: conn, drop: drop} do
      assert {:error, {:redirect, %{to: path, flash: flash}}} =
               live(conn, ~p"/drops/#{drop.id}/edit")

      assert path == ~p"/"
      assert flash["error"] == "You must log in to access this page."
    end

    test "one is redirected if drop doesn't exist", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)
      non_existent_drop_id = Ecto.UUID.generate()

      assert {:error, {:live_redirect, %{to: path}}} =
               live(conn, ~p"/drops/#{non_existent_drop_id}/edit")

      assert path == ~p"/"
    end
  end
end
