defmodule ElixirDropsWeb.UserDropLiveTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Mox
  import Phoenix.LiveViewTest

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Drops.DropsBroadcast
  alias ElixirDrops.Drops.ShortIdGenerator
  alias ElixirDrops.Workers.ScreenshotGeneratorWorker
  alias ElixirDrops.Workers.SitemapGeneratorWorker

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
          body: "Body for drop 2",
          screenshot: %{status: :completed, url: "http://example.com/screenshot.png"},
          title: "Drop 2"
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

    test "drop which has a pending screenshot status has a loader", %{conn: conn, user: user} do
      drop =
        drop_fixture(%Drop{}, user, %{
          title: "Drop With Pending Screenshot",
          body: "This is a regular drop without code blocks",
          screenshot: %{status: :pending, url: "http://example.com/old-screenshot.png"}
        })

      conn = sign_in_user(conn, user)

      {:ok, _profile_live, html} = live(conn, ~p"/profile")

      assert html =~
               "<div class=\"absolute inset-0 bg-black/40 backdrop-blur-sm rounded-lg flex items-center justify-center z-10\"><svg class=\"animate-spin h-8 w-8 text-white\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"none\" viewbox=\"0 0 24 24\"><circle class=\"opacity-25\" cx=\"12\" cy=\"12\" r=\"10\" stroke=\"currentColor\" stroke-width=\"4\"></circle><path class=\"opacity-75\" fill=\"currentColor\" d=\"M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z\"></path></svg></div>"

      {:ok, updated_drop} =
        Drops.update_drop(drop, user, %{
          screenshot: %{status: :completed, url: "http://example.com/screenshot.png"}
        })

      assert updated_drop.screenshot.status == :completed

      {:ok, _updated_live, updated_html} = live(conn, ~p"/profile")

      refute updated_html =~
               "<div class=\"absolute inset-0 bg-black/40 backdrop-blur-sm rounded-lg flex items-center justify-center z-10\"><svg class=\"animate-spin h-8 w-8 text-white\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"none\" viewbox=\"0 0 24 24\"><circle class=\"opacity-25\" cx=\"12\" cy=\"12\" r=\"10\" stroke=\"currentColor\" stroke-width=\"4\"></circle><path class=\"opacity-75\" fill=\"currentColor\" d=\"M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z\"></path></svg></div>"
    end

    test "edited drop which has a pending screenshot status has a loader", %{
      conn: conn,
      user: user
    } do
      drop =
        drop_fixture(%Drop{}, user, %{
          title: "Drop Without Code",
          body: "This is a regular drop without code blocks",
          screenshot: %{status: :completed, url: "http://example.com/old-screenshot.png"}
        })

      conn = sign_in_user(conn, user)

      {:ok, edit_live, _html} = live(conn, ~p"/drops/#{drop.short_id}/edit")

      edit_live
      |> form("#drops-editor-form",
        drop: %{
          title: "Updated Drop With Code",
          body:
            "Updated with code ```elixir\ndefmodule Test do\n  def hello do\n    :world\n  end\nend\n```"
        }
      )
      |> render_submit()

      {:ok, _profile_live, html} = live(conn, ~p"/profile")

      assert html =~
               "<div class=\"absolute inset-0 bg-black/40 backdrop-blur-sm rounded-lg flex items-center justify-center z-10\"><svg class=\"animate-spin h-8 w-8 text-white\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"none\" viewbox=\"0 0 24 24\"><circle class=\"opacity-25\" cx=\"12\" cy=\"12\" r=\"10\" stroke=\"currentColor\" stroke-width=\"4\"></circle><path class=\"opacity-75\" fill=\"currentColor\" d=\"M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z\"></path></svg></div>"

      updated_drop = Drops.get_drop(%{drop_id: drop.id})
      assert updated_drop.screenshot.status == :pending
    end

    test "drop with completed screenshot status doesn't show a loader", %{conn: conn, user: user} do
      drop =
        drop_fixture(%Drop{}, user, %{
          title: "Drop With Completed Screenshot",
          body: "```elixir\ndefmodule Test do\n  def hello do\n    :world\n  end\nend\n```",
          screenshot: %{status: :completed, url: "http://example.com/screenshot.png"}
        })

      conn = sign_in_user(conn, user)

      {:ok, _profile_live, html} = live(conn, ~p"/profile")

      assert html =~ drop.title

      refute html =~
               "<div class=\"absolute inset-0 bg-black/40 backdrop-blur-sm rounded-lg flex items-center justify-center z-10\"><svg class=\"animate-spin h-8 w-8 text-white\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"none\" viewbox=\"0 0 24 24\"><circle class=\"opacity-25\" cx=\"12\" cy=\"12\" r=\"10\" stroke=\"currentColor\" stroke-width=\"4\"></circle><path class=\"opacity-75\" fill=\"currentColor\" d=\"M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z\"></path></svg></div>"
    end

    test "updates UI when screenshot generation is completed", %{
      conn: conn,
      drop: drop,
      user: user
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

      send(
        live.pid,
        {DropsBroadcast, [:drop, :screenshot_generation_completion], drop, 100, :completed, %{}}
      )

      assert render(live) =~ "100%"
    end

    test "handles progress animation complete event", %{
      conn: conn,
      drop: drop,
      user: user
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

      html =
        live
        |> element("#screenshot-progress")
        |> render_hook("progress_animation_complete", %{
          "drop_short_id" => drop.short_id,
          "url" => "http://example.com/new-screenshot.png"
        })

      assert html =~ "100%"
      assert html =~ "http://example.com/new-screenshot.png"
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

      {:ok, updated_live, html} =
        live
        |> form("#drops-editor-form",
          drop: %{title: "New Drop title", body: "Drop body"}
        )
        |> render_submit()
        |> follow_redirect(conn, ~p"/profile")

      refute has_element?(updated_live, "#loading-spinner")
      assert html =~ "New Drop title"
    end

    test "drop needing a screenshot that gets enqueued", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)

      {:ok, live, _html} = live(conn, ~p"/drops/new")

      live
      |> form("#drops-editor-form",
        drop: %{
          title: "New Drop title",
          body: "```elixir\ndefmodule Test do\n  def hello do\n    :world\n  end\nend\n```"
        }
      )
      |> render_submit()

      Process.sleep(50)

      html = render(live)

      assert html =~ "Generating Code Screenshots..."

      assert html =~
               " Your drop is almost ready! You can close this modal—your post will continue processing in the background"

      drops = Drops.list_drops(%{user_id: user.id})
      created_drop = List.last(drops)
      assert created_drop.screenshot.status == :pending

      assert_enqueued(
        worker: ScreenshotGeneratorWorker,
        args: %{drop_id: created_drop.id},
        queue: :seo_images
      )
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

      Drops.update_drop(drop, user, %{
        screenshot: %{
          meta: %{status: :completed, url: "https://example.com/screenshot.png"},
          internal: %{status: :completed, url: "https://example.com/screenshot.png"}
        }
      })

      {:ok, _live, html} = live(conn, ~p"/d/#{drop.short_id}")

      refute html =~ ~r|<div>"Some malicious code"</div>|
      assert html =~ "Drop with script"
      assert html =~ "Some JS"
    end

    test "sitemap generation is enqueued immediately for drops without code blocks", %{
      conn: conn,
      user: user
    } do
      conn = sign_in_user(conn, user)

      {:ok, live, _html} = live(conn, ~p"/drops/new")

      live
      |> form("#drops-editor-form",
        drop: %{
          title: "New Drop Without Code",
          body: "This is a regular drop without code blocks"
        }
      )
      |> render_submit()

      drops = Drops.list_drops(%{user_id: user.id})
      created_drop = List.last(drops)
      assert created_drop.screenshot.status == :skipped

      assert_enqueued(
        worker: SitemapGeneratorWorker,
        args: %{"drop_id" => created_drop.id},
        queue: :seo_sitemap
      )
    end

    test "sitemap generation is enqueued after screenshot completion for drops with code blocks",
         %{
           conn: conn,
           user: user
         } do
      conn = sign_in_user(conn, user)

      {:ok, live, _html} = live(conn, ~p"/drops/new")

      live
      |> form("#drops-editor-form",
        drop: %{
          title: "New Drop With Code",
          body: "```elixir\ndefmodule Test do\n  def hello do\n    :world\n  end\nend\n```"
        }
      )
      |> render_submit()

      drops = Drops.list_drops(%{user_id: user.id})
      created_drop = List.last(drops)
      assert created_drop.screenshot.status == :pending

      assert_enqueued(
        worker: ScreenshotGeneratorWorker,
        args: %{"drop_id" => created_drop.id},
        queue: :seo_images
      )

      refute_enqueued(
        worker: SitemapGeneratorWorker,
        args: %{"drop_id" => created_drop.id},
        queue: :seo_sitemap
      )

      drop =
        %{user_id: user.id}
        |> Drops.list_drops()
        |> List.last()

      {:ok, updated_drop} =
        Drops.update_drop(drop, user, %{
          screenshot: %{
            status: :completed,
            meta_url: "http://example.com/screenshot.png",
            internal_url: "http://example.com/screenshot.png"
          }
        })

      DropsBroadcast.broadcast_drop_screenshot_completion(
        updated_drop,
        100,
        :completed,
        %{action: "new"}
      )

      Process.sleep(50)

      assert_enqueued(
        worker: SitemapGeneratorWorker,
        args: %{"drop_id" => updated_drop.id},
        queue: "seo_sitemap"
      )
    end
  end

  describe "/drops/:short_id/edit" do
    setup [:create_drops_setup]

    test "a drop not requiring screenshot regeneration", %{
      conn: conn,
      drop: drop,
      user: user
    } do
      conn = sign_in_user(conn, user)

      {:ok, live, html} = live(conn, ~p"/drops/#{drop.short_id}/edit")

      assert html =~ "Edit post"
      assert html =~ drop.body
      assert html =~ drop.title

      {:ok, updated_live, updated_html} =
        live
        |> form("#drops-editor-form", drop: %{title: "New Drop title", body: "New Drop body"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/profile")

      refute_enqueued(
        worker: ScreenshotGeneratorWorker,
        args: %{drop_id: drop.id},
        queue: :seo_images
      )

      assert_enqueued(
        worker: SitemapGeneratorWorker,
        args: %{"drop_id" => drop.id},
        queue: :seo_sitemap
      )

      refute has_element?(updated_live, "#loading-spinner")

      assert updated_html =~ "New Drop title"
      assert updated_drop = Drops.get_drop(%{drop_id: drop.id})
      assert updated_drop.title == "New Drop title"
      assert updated_drop.body == "New Drop body"
    end

    test "a drop to add a code block (requires screenshot regeneration)", %{
      conn: conn,
      drop: drop,
      user: user
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

      refute_enqueued(
        worker: SitemapGeneratorWorker,
        args: %{"drop_id" => drop.id},
        queue: :seo_sitemap
      )

      updated_drop = Drops.get_drop(%{drop_id: drop.id})

      DropsBroadcast.broadcast_drop_screenshot_completion(
        updated_drop,
        100,
        :completed,
        %{action: "new"}
      )

      Process.sleep(50)

      assert_enqueued(
        worker: SitemapGeneratorWorker,
        args: %{"drop_id" => updated_drop.id},
        queue: :seo_sitemap
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

    test "a drop to change part of body but not code block that the screenshot captures (does not require screenshot regeneration)",
         %{
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

      {:ok, updated_drop} =
        Drops.update_drop(drop, user, %{
          screenshot: %{
            status: :completed,
            meta_url: "http://example.com/screenshot.png",
            internal_url: "http://example.com/screenshot.png"
          }
        })

      conn = sign_in_user(conn, user)

      {:ok, live, _html} = live(conn, ~p"/drops/#{updated_drop.short_id}/edit")

      live
      |> form("#drops-editor-form",
        drop: %{
          title: "New Drop title",
          body:
            "Edited body but not code block ```elixir\ndefmodule Test do\n  def hello do\n    :world\n  end\nend\n```"
        }
      )
      |> render_submit()

      {:ok, _view, _html} = live(conn, ~p"/profile")

      drop_from_db = Drops.get_drop(%{drop_id: updated_drop.id})

      assert drop_from_db.screenshot.status == :completed
      assert drop_from_db.screenshot.meta_url == "http://example.com/screenshot.png"
      assert drop_from_db.screenshot.internal_url == "http://example.com/screenshot.png"
    end

    test "a drop with more than one code block does not require screenshot regeneration when a code block other than the first is edited",
         %{
           conn: conn,
           user: user
         } do
      drop =
        drop_fixture(%Drop{}, user, %{
          body:
            "```elixir\ndefmodule Test do\n  def hello do\n    :world\n  end\nend\n``` ```second code block```"
        })

      {:ok, updated_drop} =
        Drops.update_drop(drop, user, %{
          screenshot: %{
            status: :completed,
            meta_url: "http://example.com/screenshot.png",
            internal_url: "http://example.com/screenshot.png"
          }
        })

      conn = sign_in_user(conn, user)

      {:ok, live, _html} = live(conn, ~p"/drops/#{updated_drop.short_id}/edit")

      live
      |> form("#drops-editor-form",
        drop: %{
          title: "New Drop title",
          body:
            "```elixir\ndefmodule Test do\n  def hello do\n    :world\n  end\nend\n``` ```second code block edited```"
        }
      )
      |> render_submit()

      refute_enqueued(
        worker: ScreenshotGeneratorWorker,
        args: %{drop_id: updated_drop.id},
        queue: :seo_images
      )

      {:ok, _view, _html} = live(conn, ~p"/profile")

      drop_from_db = Drops.get_drop(%{drop_id: updated_drop.id})

      assert drop_from_db.screenshot.status == :completed
      assert drop_from_db.screenshot.meta_url == "http://example.com/screenshot.png"
      assert drop_from_db.screenshot.internal_url == "http://example.com/screenshot.png"
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

    test "screenshot job uses correct old body value when updating drop", %{
      conn: conn,
      user: user
    } do
      drop = drop_fixture(%Drop{}, user, %{title: "Drop title", body: "No code block"})

      conn = sign_in_user(conn, user)
      old_body = drop.body

      new_body =
        "#{old_body} with a change ```elixir\ndefmodule Test do\n  def hello do\n    :world\n  end\nend\n edited code block```"

      {:ok, live, _html} = live(conn, ~p"/drops/#{drop.short_id}/edit")

      live
      |> form("#drops-editor-form", drop: %{body: new_body})
      |> render_submit()

      assert_enqueued(
        worker: ScreenshotGeneratorWorker,
        args: %{
          "drop_id" => drop.id,
          "old_body" => old_body,
          "action" => "edit"
        },
        queue: :seo_images
      )
    end
  end
end
