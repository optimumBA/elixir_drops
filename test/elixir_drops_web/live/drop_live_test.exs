defmodule ElixirDropsWeb.DropLiveTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Mox
  import Phoenix.LiveViewTest

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Drops.ShortIdGenerator
  alias ElixirDrops.S3Helper.Client

  setup :verify_on_exit!

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

      {:ok, _time} =
        Timex.format(drop.inserted_at, "{relative}", :relative)

      assert html =~ drop.title
      assert html =~ user.github_username
      assert html =~ user.avatar
      assert html =~ ~s(datetime="#{drop.inserted_at}Z")
    end

    test "user can navigate to view a drop", %{conn: conn, drop: drop} do
      {:ok, live, _html} = live(conn, ~p"/")

      live
      |> element("#drop-#{drop.id}")
      |> render_click()

      {path, _flash} = assert_redirect(live)

      assert path == ~p"/d/#{drop.short_id}"
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

  describe "/d/:short_id" do
    setup [:create_drops_setup]

    test "user can view a drop", %{conn: conn, drop: drop, user: user} do
      expect(Client.Mock, :get_image, 2, fn _drop ->
        {:error, "Image not found"}
      end)

      {:ok, _live, html} = live(conn, ~p"/d/#{drop.short_id}")

      {:ok, _time} =
        Timex.format(drop.inserted_at, "{relative}", :relative)

      assert html =~ ~r(<p>Drop body text...</p>)
      assert html =~ drop.title
      assert html =~ user.github_username
      assert html =~ user.avatar
      assert html =~ ~s(datetime="#{drop.inserted_at}Z")
    end

    test "user redirected to home page when drop does not exist", %{conn: conn} do
      short_id = ShortIdGenerator.generate()
      path = "/"

      assert {:error, {:live_redirect, %{to: ^path}}} =
               live(conn, ~p"/d/#{short_id}")
    end

    test "Javascript code inside the drop is not executed", %{conn: conn, user: user} do
      drop =
        drop_fixture(
          %Drop{},
          user,
          %{
            body:
              "User drop with JS\n\n```js\n<script>\nlet header = document.querySelector('header')\n\nconst tempDiv = document.createElement(\"div\");\ntempDiv.textContent = \"Some malicious code\";\n\nheader.insertAdjacentElement('afterend', tempDiv);\n</script>\n```",
            title: "Drop with script"
          }
        )

      expect(Client.Mock, :get_image, 2, fn _drop ->
        {:ok, "http://image.com/drop-meta-image-#{user.id}-#{drop.id}.png"}
      end)

      {:ok, _live, html} = live(conn, ~p"/d/#{drop.short_id}")

      refute html =~ ~r|<div>"Some malicious code"</div>|
      assert html =~ "Drop with script"
      assert html =~ "User drop with JS"
    end

    test "rendered HTML includes SEO meta tags for drop", %{
      conn: conn,
      drop: drop
    } do
      expect(Client.Mock, :get_image, 2, fn _drop ->
        {:error, "Image not found"}
      end)

      {:ok, _live, html} = live(conn, ~p"/d/#{drop.short_id}")

      assert html =~ "<meta name=\"twitter:card\" content=\"summary_large_image\"/>"
      assert html =~ "<meta name=\"twitter:description\" content=\"#{drop.title}...\"/>"

      assert html =~
               "<meta name=\"twitter:image\" content=\"http://localhost:4002/images/seo_default_image.png\"/>"

      assert html =~ "<meta name=\"twitter:site\" content=\"@optimumBA\"/>"

      assert html =~
               "<meta name=\"twitter:url\" content=\"http://localhost:4002/d/#{drop.short_id}\"/>"

      assert html =~
               "<meta property=\"description\" content=\"#{drop.title}...\"/>"

      assert html =~
               "<meta property=\"og:description\" content=\"#{drop.title}...\"/>"

      assert html =~
               "<meta property=\"og:image\" content=\"http://localhost:4002/images/seo_default_image.png\"/>"

      assert html =~ "<meta property=\"og:title\" content=\"Elixir Drops\"/>"
      assert html =~ "<meta property=\"og:type\" content=\"article\"/>"

      assert html =~
               "<meta property=\"og:url\" content=\"http://localhost:4002/d/#{drop.short_id}\"/>"
    end

    test "links are escaped and images are omitted from the description", %{
      conn: conn,
      user: user
    } do
      drop_attributes = %{
        description: "Drop body",
        title: "[In this drop](http://localhost:4002/good_drop) we discussed stuff"
      }

      drop = drop_fixture(%Drop{}, user, drop_attributes)

      expect(Client.Mock, :get_image, 2, fn _drop ->
        {:error, "Image not found"}
      end)

      {:ok, _live, html} = live(conn, ~p"/d/#{drop.short_id}")

      assert html =~
               "<meta property=\"description\" content=\"In this drop we discussed stuff...\"/>"

      assert html =~
               "<meta property=\"og:description\" content=\"In this drop we discussed stuff...\"/>"

      assert html =~
               "<meta name=\"twitter:description\" content=\"In this drop we discussed stuff...\"/>"
    end
  end
end
