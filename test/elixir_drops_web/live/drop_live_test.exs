defmodule ElixirDropsWeb.DropLiveTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Mox
  import Phoenix.LiveViewTest

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Drops.DropsBroadcast
  alias ElixirDrops.Drops.ShortIdGenerator

  setup :verify_on_exit!

  defp create_drops_setup(%{conn: conn}) do
    conn =
      put_connect_params(
        conn,
        %{
          "show_welcome_message" => "true"
        }
      )

    user = user_fixture(%{github_id: 1_456_872})
    user2 = user_fixture(%{github_id: 9_456_872})
    drop = drop_fixture(user)

    %{conn: conn, drop: drop, user: user, user2: user2}
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

    test "shows a list of drops with screenshot status :completed", %{
      conn: conn,
      drop: drop,
      user: user
    } do
      drop1 = drop_fixture(user)
      drop2 = drop_fixture(user)

      {:ok, pending_drop} =
        Drops.update_drop_screenshot(drop1, %{screenshot: %{status: :pending}})

      {:ok, failed_drop} = Drops.update_drop_screenshot(drop2, %{screenshot: %{status: :failed}})

      {:ok, completed_drop} =
        Drops.update_drop_screenshot(drop, %{screenshot: %{status: :completed}})

      {:ok, _live, html} = live(conn, ~p"/")

      {:ok, _time} =
        Timex.format(completed_drop.inserted_at, "{relative}", :relative)

      assert html =~ completed_drop.title
      assert html =~ user.github_username
      assert html =~ user.avatar
      assert html =~ ~s(datetime="#{completed_drop.inserted_at}Z")

      refute html =~ pending_drop.title
      refute html =~ failed_drop.title
    end

    test "shows a list of drops with screenshot status :skipped and :completed", %{
      conn: conn,
      drop: drop,
      user: user
    } do
      completed_drop = drop_fixture(user)
      {:ok, skipped_drop} = Drops.update_drop_screenshot(drop, %{screenshot: %{status: :skipped}})

      {:ok, _live, html} = live(conn, ~p"/")

      assert html =~ completed_drop.title
      assert html =~ skipped_drop.title
      assert html =~ user.github_username
      assert html =~ user.avatar
    end

    test "user can navigate to view a drop", %{conn: conn, drop: drop} do
      {:ok, live, _html} = live(conn, ~p"/")

      live
      |> element("#drop-#{drop.id}")
      |> render_click()

      {path, _flash} = assert_redirect(live)

      assert path == ~p"/d/#{drop.short_id}"
    end

    test "unathorized users cannot edit drops", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/")

      refute html =~ "Edit drop"
    end

    test "only the author can edit a drop", %{
      conn: conn,
      user: user,
      user2: user2
    } do
      conn = sign_in_user(conn, user)
      {:ok, _live, html} = live(conn, ~p"/")

      assert html =~ "Edit drop"

      conn2 = sign_in_user(conn, user2)
      {:ok, _live, html2} = live(conn2, ~p"/")

      refute html2 =~ "Edit drop"
    end

    test "user gets updated with new a drop not requiring screenshot generation", %{
      conn: conn,
      user: user
    } do
      {:ok, live, _html} = live(conn, ~p"/")

      refute has_element?(live, "#new-drops-indicator")

      {:ok, drop} =
        Drops.create_drop(%Drop{}, user, %{
          body: "Drop body with code block",
          screenshot: %{
            status: :completed,
            url: "http://example.com/screenshot.png"
          },
          title: "New Drop title"
        })

      assert has_element?(live, "#new-drops-indicator")

      live
      |> element("#new-drops-indicator")
      |> render_click()

      assert has_element?(live, "#drop-#{drop.id}", drop.title)
    end

    test "user sees an indicator for new drop only when screenshot generation completes",
         %{
           conn: conn,
           user: user
         } do
      Drops.subscribe()

      {:ok, live, _html} = live(conn, ~p"/")

      refute has_element?(live, "#new-drops-indicator")

      {:ok, drop} =
        Drops.create_drop(%Drop{}, user, %{
          title: "New Drop title",
          body:
            "Drop body ```elixir\ndefmodule Test do\n  def hello do\n    :world\n  end\nend\n```",
          screenshot: %{status: :pending}
        })

      refute has_element?(live, "#new-drops-indicator")

      refute has_element?(live, "#drop-#{drop.id}")

      {:ok, updated_drop} =
        Drops.update_drop_screenshot(drop, %{
          screenshot: %{status: :completed, url: "http://example.com/screenshot.png"}
        })

      DropsBroadcast.broadcast_drop_screenshot_completion(
        updated_drop,
        100,
        :completed,
        %{action: "new"}
      )

      Process.sleep(100)

      render(live)

      assert has_element?(live, "#new-drops-indicator")

      live
      |> element("#new-drops-indicator")
      |> render_click()

      assert has_element?(live, "#drop-#{drop.id}")
    end

    test "user does not see an indicator when an existing drop's screenshot is regenerated",
         %{
           conn: conn,
           user: user
         } do
      {:ok, drop} =
        Drops.create_drop(%Drop{}, user, %{
          title: "Existing Drop title",
          body:
            "Drop body with code ```elixir\ndefmodule Test do\n  def hello do\n    :world\n  end\nend\n```",
          screenshot: %{status: :completed, url: "http://example.com/screenshot.png"}
        })

      Drops.subscribe()

      {:ok, live, _html} = live(conn, ~p"/")

      assert has_element?(live, "#drop-#{drop.id}")

      refute has_element?(live, "#new-drops-indicator")

      {:ok, updated_drop} =
        Drops.update_drop_screenshot(drop, %{
          screenshot: %{status: :pending, url: nil}
        })

      {:ok, completed_drop} =
        Drops.update_drop_screenshot(updated_drop, %{
          screenshot: %{status: :completed, url: "http://example.com/new-screenshot.png"}
        })

      DropsBroadcast.broadcast_drop_screenshot_completion(
        completed_drop,
        100,
        :completed,
        %{action: "edit"}
      )

      Process.sleep(100)

      render(live)

      refute has_element?(live, "#new-drops-indicator")

      assert has_element?(live, "#drop-#{drop.id}")
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
      refute html =~ midpoint_drop.id
      refute html =~ first_drop.id
      assert html_2 = render_hook(live, "load-more", %{})

      refute html_2 =~ first_drop.id
      assert html_2 =~ midpoint_drop.id
      assert html_3 = render_hook(live, "load-more", %{})
      assert html_3 =~ first_drop.id
    end
  end

  describe "/d/:short_id" do
    setup [:create_drops_setup]

    test "user can view a drop", %{conn: conn, user: user} do
      drop = drop_fixture(%Drop{}, user, %{title: "Drop title", body: "Drop body text..."})

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

      {:ok, _live, html} = live(conn, ~p"/d/#{drop.short_id}")

      refute html =~ ~r|<div>"Some malicious code"</div>|
      assert html =~ "Drop with script"
      assert html =~ "User drop with JS"
    end

    test "rendered HTML includes SEO meta tags for drop", %{
      conn: conn,
      drop: drop
    } do
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

      Drops.update_drop_screenshot(drop, %{
        screenshot: %{
          status: :completed,
          url: "http://image.com/drop-meta-image-latest-#{drop.id}.png"
        }
      })

      {:ok, _live, updated_html} = live(conn, ~p"/d/#{drop.short_id}")

      assert updated_html =~
               "<meta property=\"og:image\" content=\"http://image.com/drop-meta-image-latest-#{drop.id}.png\"/>"

      assert updated_html =~
               "<meta name=\"twitter:image\" content=\"http://image.com/drop-meta-image-latest-#{drop.id}.png\"/>"
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

      {:ok, _live, html} = live(conn, ~p"/d/#{drop.short_id}")

      assert html =~
               "<meta property=\"description\" content=\"In this drop we discussed stuff...\"/>"

      assert html =~
               "<meta property=\"og:description\" content=\"In this drop we discussed stuff...\"/>"

      assert html =~
               "<meta name=\"twitter:description\" content=\"In this drop we discussed stuff...\"/>"
    end
  end

  describe "close editor button" do
    setup [:create_drops_setup]

    test "closing editor navigates to profile page when confirmed",
         %{
           conn: conn,
           user: user
         } do
      conn = sign_in_user(conn, user)

      {:ok, live, html} = live(conn, ~p"/drops/new")
      assert html =~ "Write a new post"

      live
      |> element("#confirm-close-editor-button")
      |> render_click()

      {path, _flash} = assert_redirect(live)

      assert path == "/profile"
    end
  end
end
