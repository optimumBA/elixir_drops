defmodule ElixirDropsWeb.UserDropLiveTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Mox
  import Phoenix.LiveViewTest

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Drops.ShortIdGenerator
  alias ElixirDrops.S3Helper.Client
  alias ElixirDrops.Workers.ScreenshotGeneratorWorker

  setup :verify_on_exit!

  defp create_drops_setup(%{conn: conn}) do
    conn = put_connect_params(conn, %{"timezone_offset" => 0})
    user = user_fixture()
    drop = drop_fixture(user)

    %{conn: conn, drop: drop, user: user}
  end

  describe "/profile" do
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

      {:ok, _live, html} = live(conn, ~p"/profile")

      assert html =~ drop.title
      assert html =~ user.github_username
      refute html =~ drop_2.title
      refute html =~ user_2.github_username
    end

    test "unauthorized users are redirected", %{conn: conn} do
      assert {:error,
              {
                :redirect,
                %{to: path, flash: flash}
              }} =
               live(conn, ~p"/profile")

      assert flash["error"] == "You must log in to access this page."
      assert path == ~p"/"
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

      conn = sign_in_user(conn, user)
      {:ok, live, html} = live(conn, ~p"/profile")

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

      conn = sign_in_user(conn, user)
      {:ok, live, html} = live(conn, ~p"/profile")
      assert html =~ last_drop.id

      assert html_2 = render_hook(live, "next-page", %{})
      assert html_2 =~ midpoint_drop.id

      assert html_3 = render_hook(live, "prev-page", %{})
      assert html_3 =~ last_drop.id
      refute html_3 =~ first_drop.id
    end

    test "user can navigate drops with infinite scroll and handle overrun condition", %{
      conn: conn,
      user: user
    } do
      drops = create_multiple_drops(user, 25)

      conn = sign_in_user(conn, user)
      {:ok, live, html} = live(conn, ~p"/profile")

      first_drop = List.first(drops)
      last_drop = List.last(drops)

      assert html =~ last_drop.id
      refute html =~ first_drop.id

      assert html_after_overrun = render_hook(live, "prev-page", %{"_overran" => true})

      refute html_after_overrun =~ first_drop.id
      assert html_after_overrun =~ last_drop.id
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
        |> follow_redirect(conn, ~p"/profile")

      assert html =~ "New Drop title"
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

    test "Javascript code inside the drop is not executed in the preview", %{
      conn: conn,
      user: user
    } do
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

      expect(Client.Mock, :get_image, 2, fn _drop ->
        {:ok, "http://image.com/drop-meta-image-#{user.id}-#{drop.id}.png"}
      end)

      {:ok, _live, html} = live(conn, ~p"/d/#{drop.short_id}")

      refute html =~ ~r|<div>"Some malicious code"</div>|
      assert html =~ "Drop with script"
      assert html =~ "Some JS"
    end
  end

  describe "/drops/:short_id/edit" do
    setup [:create_drops_setup]

    test "authorized user updates a drop", %{conn: conn, user: user, drop: drop} do
      conn = sign_in_user(conn, user)

      {:ok, live, html} = live(conn, ~p"/drops/#{drop.short_id}/edit")

      assert html =~ "Edit post"
      assert html =~ drop.body
      assert html =~ drop.title

      {:ok, _live, updated_html} =
        live
        |> form("#drops-editor-form", drop: %{title: "New Drop title", body: "New Drop body"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/profile")

      assert updated_html =~ "New Drop title"

      assert updated_drop = Drops.get_drop(%{drop_id: drop.id})
      assert updated_drop.title == "New Drop title"
      assert updated_drop.body == "New Drop body"
    end

    test "authorized user cannot update a drop with invalid data", %{
      conn: conn,
      drop: drop,
      user: user
    } do
      conn = sign_in_user(conn, user)

      {:ok, live, _html} = live(conn, ~p"/drops/#{drop.short_id}/edit")

      html =
        live
        |> form("#drops-editor-form", drop: %{title: "", body: "New Drop body"})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "a user cannot edit another user's drop", %{conn: conn, drop: drop} do
      user_2 =
        user_fixture(%{
          avatar: "https://avatars.githubusercontent.com/u/1456872?v=4",
          email: "user2@mail.com",
          github_id: 12_345,
          github_username: "github_username",
          name: "some_name"
        })

      conn = sign_in_user(conn, user_2)

      assert {:error, {:live_redirect, %{to: path}}} =
               live(conn, ~p"/drops/#{drop.short_id}/edit")

      assert path == ~p"/"
    end

    test "an image upload job is enqueued when a drop is updated", %{
      conn: conn,
      drop: drop,
      user: user
    } do
      conn = sign_in_user(conn, user)

      {:ok, live, html} = live(conn, ~p"/drops/#{drop.short_id}/edit")

      assert html =~ "Edit post"
      assert html =~ drop.body
      assert html =~ drop.title

      live
      |> form("#drops-editor-form", drop: %{title: "New Drop title", body: "New Drop body"})
      |> render_submit()

      assert_enqueued(
        worker: ScreenshotGeneratorWorker,
        args: %{drop_id: drop.id},
        queue: :seo_images
      )
    end

    test "unauthorized users are redirected", %{conn: conn, drop: drop} do
      assert {:error, {:redirect, %{to: path, flash: flash}}} =
               live(conn, ~p"/drops/#{drop.short_id}/edit")

      assert path == ~p"/"
      assert flash["error"] == "You must log in to access this page."
    end

    test "one is redirected if drop doesn't exist", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)

      non_existent_drop_short_id = ShortIdGenerator.generate()

      assert {:error, {:live_redirect, %{to: path}}} =
               live(conn, ~p"/drops/#{non_existent_drop_short_id}/edit")

      assert path == ~p"/"
    end
  end
end
