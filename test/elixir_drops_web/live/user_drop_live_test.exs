defmodule ElixirDropsWeb.UserDropLiveTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Mox
  import Phoenix.LiveViewTest

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  # alias ElixirDrops.Drops.DropsBroadcast
  alias ElixirDrops.Drops.ShortIdGenerator
  alias ElixirDrops.S3Helper.Client
  alias ElixirDrops.Workers.ScreenshotGeneratorWorker

  setup :verify_on_exit!

  defp create_drops_setup(%{conn: conn}) do
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

      drop_2 =
        drop_fixture(%Drop{}, user_2, %{
          title: "Drop 2",
          body: "Body for drop 2",
          screenshot_status: "published"
        })

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
      refute html =~ midpoint_drop.id
      refute html =~ first_drop.id

      assert html_2 = render_hook(live, "load-more", %{})
      refute html_2 =~ first_drop.id
      assert html_2 =~ midpoint_drop.id
      assert html_2 =~ last_drop.id

      assert html_3 = render_hook(live, "load-more", %{})
      assert html_3 =~ first_drop.id
    end
  end

  describe "/drop/new" do
    setup [:create_drops_setup]

    test "drop not needing a screenshot can be created by authorized users", %{
      conn: conn,
      user: user
    } do
      conn = sign_in_user(conn, user)

      {:ok, live, _html} = live(conn, ~p"/drops/new")

      {:ok, live, html} =
        live
        |> form("#drops-editor-form",
          drop: %{title: "New Drop title", body: "Drop body"}
        )
        |> render_submit()
        |> follow_redirect(conn, ~p"/profile")

      refute has_element?(live, "#loading-spinner")
      assert html =~ "New Drop title"
    end

    test "drop needing a screenshot that gets enqueued", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)

      {:ok, live, _html} = live(conn, ~p"/drops/new")

      html =
        live
        |> form("#drops-editor-form",
          drop: %{
            title: "New Drop title",
            body: "```elixir\ndefmodule Test do\n  def hello do\n    :world\n  end\nend\n```"
          }
        )
        |> render_submit()

      drops = Drops.list_drops(%{user_id: user.id})
      created_drop = List.last(drops)

      assert_enqueued(
        worker: ScreenshotGeneratorWorker,
        args: %{drop_id: created_drop.id},
        queue: :seo_images
      )

      assert created_drop.screenshot_status == "pending"

      assert html =~ "Generating Code Screenshots..."

      assert html =~
               " Your Drop Post is almost ready! You can close this modal—your post will continue processing in the background"
    end

    test "drop screenshot generation progress", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)

      {:ok, live, _html} = live(conn, ~p"/drops/new")

      html =
        live
        |> form("#drops-editor-form",
          drop: %{
            title: "New Drop title",
            body: "```elixir\ndefmodule Test do\n  def hello do\n    :world\n  end\nend\n```"
          }
        )
        |> render_submit()

      # It passes but not sure about it
      assert html =~ "50%"

      assert html =~ "You can now view and share your drop post."
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

    test "a drop not requiring screenshot regeneration", %{
      conn: conn,
      user: user,
      drop: drop
    } do
      conn = sign_in_user(conn, user)

      {:ok, live, html} = live(conn, ~p"/drops/#{drop.short_id}/edit")

      assert html =~ "Edit post"
      assert html =~ drop.body
      assert html =~ drop.title

      {:ok, live, updated_html} =
        live
        |> form("#drops-editor-form", drop: %{title: "New Drop title", body: "New Drop body"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/profile")

      refute_enqueued(
        worker: ScreenshotGeneratorWorker,
        args: %{drop_id: drop.id},
        queue: :seo_images
      )

      refute has_element?(live, "#loading-spinner")

      assert updated_html =~ "New Drop title"
      assert updated_drop = Drops.get_drop(%{drop_id: drop.id})
      assert updated_drop.title == "New Drop title"
      assert updated_drop.body == "New Drop body"
    end

    test "a drop to add a code block (requires screenshot regeneration)", %{
      conn: conn,
      user: user,
      drop: drop
    } do
      conn = sign_in_user(conn, user)

      {:ok, live, _html} = live(conn, ~p"/drops/#{drop.short_id}/edit")

      live
      |> form("#drops-editor-form",
        drop: %{
          title: "New Drop title",
          body: "```elixir\ndefmodule Test do\n  def hello do\n    :world\n  end\nend\n```"
        }
      )
      |> render_submit()

      assert_enqueued(
        worker: ScreenshotGeneratorWorker,
        args: %{drop_id: drop.id},
        queue: :seo_images
      )
    end

    test "updates a drop to remove a code block (does not require screenshot regeneration)", %{
      conn: conn,
      user: user
    } do
      drop =
        drop_fixture(
          %Drop{},
          user,
          %{
            body: "```elixir\ndefmodule Test do\n  def hello do\n    :world\n  end\nend\n```",
            title: "Drop with code block"
          }
        )

      conn = sign_in_user(conn, user)

      {:ok, live, _html} = live(conn, ~p"/drops/#{drop.short_id}/edit")

      live
      |> form("#drops-editor-form",
        drop: %{title: "New Drop title", body: "New Drop body without code block"}
      )
      |> render_submit()
      |> follow_redirect(conn, ~p"/profile")

      refute_enqueued(
        worker: ScreenshotGeneratorWorker,
        args: %{drop_id: drop.id},
        queue: :seo_images
      )
    end

    test "a drop to edit a code block (requires screenshot regeneration)", %{
      conn: conn,
      user: user
    } do
      drop =
        drop_fixture(
          %Drop{},
          user,
          %{
            body: "```elixir\ndefmodule Test do\n  def hello do\n    :world\n  end\nend\n```",
            title: "Drop with code block"
          }
        )

      conn = sign_in_user(conn, user)

      {:ok, live, _html} = live(conn, ~p"/drops/#{drop.short_id}/edit")

      live
      |> form("#drops-editor-form",
        drop: %{
          title: "New Drop title",
          body:
            "New Drop body with edited code block ```elixir\ndefmodule Test do\n  def hello do\n    :world\n  end\nend\n edited code block```"
        }
      )
      |> render_submit()

      assert_enqueued(
        worker: ScreenshotGeneratorWorker,
        args: %{drop_id: drop.id},
        queue: :seo_images
      )
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
