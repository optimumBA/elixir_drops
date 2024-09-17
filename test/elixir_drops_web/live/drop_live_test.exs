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

    test "unauthorized users are prohibited from creating drops", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      live
      |> element("#create-post-button")
      |> render_click()

      assert :ok = refute_redirected(live, ~p"/drops/new")
    end

    test "authorized users can navigate to the drop creation page", %{conn: conn, user: user} do
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

    test "user can view older drops with infinite scroll", %{conn: conn, user: user} do
      drops = create_multiple_drops(user, 25)

      list_midpoint =
        drops
        |> length()
        |> div(2)

      first_drop = List.first(drops)
      last_drop = List.last(drops)
      midpoint_drop = Enum.at(drops, list_midpoint)

      {:ok, live, html} = live(conn, ~p"/")

      assert html =~ last_drop.id
      refute html =~ midpoint_drop.id
      refute html =~ first_drop.id

      assert html_2 = render_hook(live, "next-page", %{})
      assert html_2 =~ midpoint_drop.id
      refute html_2 =~ first_drop.id

      assert html_3 = render_hook(live, "next-page", %{})
      assert html_3 =~ first_drop.id
    end

    test "user can view newer drops with infinite scroll", %{conn: conn, user: user} do
      drops = create_multiple_drops(user, 25)

      list_midpoint =
        drops
        |> length()
        |> div(2)

      first_drop = List.first(drops)
      last_drop = List.last(drops)
      midpoint_drop = Enum.at(drops, list_midpoint)

      {:ok, live, html} = live(conn, ~p"/")
      assert html =~ last_drop.id

      assert html_2 = render_hook(live, "next-page", %{})
      assert html_2 =~ midpoint_drop.id

      assert html_3 = render_hook(live, "prev-page", %{})
      assert html_3 =~ last_drop.id
      refute html_3 =~ first_drop.id
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

    test "Javascript code inside the drop is not executed", %{conn: conn, user: user} do
      drop =
        drop_fixture(
          %Drop{},
          user,
          %{
            body:
              "Some JS\n\n```js\n<script>\nlet header = document.querySelector('header')\n\nconst tempDiv = document.createElement(\"div\");\ntempDiv.textContent = \"Some malicious code\";\n\nheader.insertAdjacentElement('afterend', tempDiv);\n</script>\n```",
            title: "Drop with script"
          }
        )

      {:ok, _live, html} = live(conn, ~p"/drops/#{drop.id}")

      refute html =~ ~r|<div>"Some malicious code"</div>|
      assert html =~ "Drop with script"
      assert html =~ "Some JS"
    end
  end
end
