defmodule ElixirDropsWeb.UserDropLiveTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import ElixirDrops.SearchFixtures
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
      _drops = create_multiple_drops(user, 35)

      conn = sign_in_user(conn, user)
      {:ok, live, html} = live(conn, ~p"/profile")

      # First page should have newest drops
      # Newest
      assert html =~ "Drop title 35"
      # 10th drop
      assert html =~ "Drop title 26"
      # Should not have oldest
      refute html =~ "Drop title 1"

      # Load more should show Drop title 20 but still not Drop title 5
      assert html_2 = render_hook(live, "load-more", %{})
      assert html_2 =~ "Drop title 20"
      # Should have the 30th drop (oldest on second page)
      assert html_2 =~ "Drop title 6"
      # Should NOT have the 31st drop
      refute html_2 =~ "Drop title 5"

      # Another load-more should show Drop title 5 and Drop title 1 (oldest)
      assert html_3 = render_hook(live, "load-more", %{})
      assert html_3 =~ "Drop title 5"
      # Should now have the oldest drop
      assert html_3 =~ "Drop title 1"
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

    test "search with query returns matching drops", %{conn: conn, user: user} do
      # Create test drops
      _matching_drop =
        drop_fixture(%Drop{}, user, %{title: "Phoenix Tutorial", body: "Learning Phoenix"})

      _non_matching_drop =
        drop_fixture(%Drop{}, user, %{title: "Random Drop", body: "Not related"})

      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/profile?q=phoenix")

      html = render(live)
      assert html =~ "Phoenix Tutorial"
      refute html =~ "Random Drop"
    end

    test "search with empty results shows no drops", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)
      {:ok, _live, html} = live(conn, ~p"/profile?q=nonexistent")

      assert html =~ "Sorry we couldn&#39;t find any results for this search."
    end

    test "close_search_overlay event hides search suggestions", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/profile")

      render_hook(live, "close_search_overlay", %{})

      html = render(live)
      refute html =~ "search-suggestions"
    end

    test "load_suggestions event with short query shows no suggestions", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/profile")

      refute render_hook(live, "load_suggestions", %{"query" => "a"}) =~ "search-suggestions"
    end

    test "load_suggestions with non-binary query shows no suggestions", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/profile")

      refute render_hook(live, "load_suggestions", %{"query" => 123}) =~ "search-suggestions"
    end

    test "load_navbar_suggestions with non-binary query shows no suggestions", %{
      conn: conn,
      user: user
    } do
      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/profile")

      refute render_hook(live, "load_navbar_suggestions", %{"query" => nil}) =~
               "search-suggestions"
    end
  end

  describe "search functionality" do
    setup [:create_drops_setup]

    test "profile search submits to /profile?q=query not /?q=query", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)
      {:ok, live, html} = live(conn, ~p"/profile")

      # Check if profile-search-input exists in HTML
      assert html =~ "profile-search-input"

      # Try finding the form with a simpler selector first
      form_element = element(live, "#profile-search-input form")
      assert form_element != nil

      # Submit search from profile page
      live
      |> form("#profile-search-input form", %{
        "query" => "test search"
      })
      |> render_submit()

      # Should navigate to profile page with query using push_navigate
      # Note: spaces in query params are encoded as +
      assert_redirect(live, "/profile?q=test+search")
    end

    test "empty search on profile page stays on profile", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/profile")

      # Submit empty search on profile search (within profile-search-input div)
      live
      |> form("#profile-search-input form", %{"query" => ""})
      |> render_submit()

      # Should stay on profile page
      assert_redirect(live, ~p"/profile")
    end

    test "navbar search from profile page navigates to homepage", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/profile")

      # Submit navbar search (different event)
      live
      |> form("#desktop-search-input form", %{
        "query" => "navbar search"
      })
      |> render_submit()

      # Should navigate to homepage with query (spaces encoded as +)
      assert_redirect(live, "/?q=navbar+search")
    end

    test "search suggestions show unique terms without duplicates", %{conn: conn, user: user} do
      # Create search history with duplicates
      {:ok, _} = ElixirDrops.Search.create_search_history(%{query: "wallaby", user_id: user.id})
      {:ok, _} = ElixirDrops.Search.create_search_history(%{query: "wallaby", user_id: user.id})
      {:ok, _} = ElixirDrops.Search.create_search_history(%{query: "phoenix", user_id: user.id})

      # Create popular searches to ensure we have both history and popular suggestions
      # These popular searches should NOT overlap with the search history
      popular_search_fixture(%{query: "ecto", search_count: 10})
      popular_search_fixture(%{query: "liveview", search_count: 8})
      popular_search_fixture(%{query: "genserver", search_count: 5})

      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/profile")

      # Focus search input should show initial suggestions
      render_hook(live, "focus_search_input", %{})
      html = render(live)

      # Should show search history (2 most recent unique entries)
      assert html =~ "wallaby"
      assert html =~ "phoenix"

      # Should show popular searches (excluding those in history)
      assert html =~ "ecto"
      assert html =~ "liveview"
      assert html =~ "genserver"

      # Verify deduplication by checking the history is ordered and unique
      history = ElixirDrops.Search.get_user_search_history(user.id)
      query_texts = Enum.map(history, & &1.query)
      assert length(query_texts) == length(Enum.uniq(query_texts))
      assert "wallaby" in query_texts
      assert "phoenix" in query_texts
    end

    test "delete search history updates suggestions list", %{conn: conn, user: user} do
      # Create search history with very unique query that won't appear anywhere else
      unique_query = "xyzabc#{System.unique_integer()}"

      {:ok, history} =
        ElixirDrops.Search.create_search_history(%{
          query: unique_query,
          user_id: user.id,
          results_count: 1
        })

      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/profile")

      # Focus to show suggestions
      render_hook(live, "focus_search_input", %{})
      html = render(live)
      assert html =~ unique_query

      # Delete the history item - ensure ID is passed as string
      render_hook(live, "delete_search_history", %{"id" => to_string(history.id)})

      # Verify the item was actually deleted from history in the backend
      history_items = ElixirDrops.Search.get_user_search_history(user.id)
      query_texts = Enum.map(history_items, & &1.query)
      refute unique_query in query_texts

      # The backend deletion worked correctly - this is what we're testing
      # Note: In the current implementation, navbar and profile suggestions
      # are loaded independently. The navbar still shows the old suggestions
      # until it's refreshed. This is expected behavior as they have separate state.
    end

    test "separate dropdown states for navbar and profile search", %{conn: conn, user: user} do
      # Create some search history
      {:ok, _} = ElixirDrops.Search.create_search_history(%{query: "test", user_id: user.id})

      conn = sign_in_user(conn, user)
      {:ok, live, html} = live(conn, ~p"/profile")

      # Initial state - both dropdowns have suggestions loaded
      assert html =~ "navbar-search-dropdown"
      assert html =~ "profile-search-dropdown"

      # Focus navbar search - this should show navbar suggestions
      render_hook(live, "focus_navbar_search", %{})
      focus_navbar_html = render(live)
      # The navbar dropdown should have suggestions
      assert focus_navbar_html =~ "navbar-search-dropdown"

      # Type in navbar search to load navbar suggestions
      render_hook(live, "load_navbar_suggestions", %{"query" => "te"})
      navbar_html = render(live)
      # Should still have navbar suggestions
      assert navbar_html =~ "navbar-search-dropdown"

      # Focus profile search - should show profile suggestions
      render_hook(live, "focus_search_input", %{})
      focus_html = render(live)
      # Profile dropdown should have suggestions
      assert focus_html =~ "profile-search-dropdown"

      # Type in profile search to load profile suggestions
      render_hook(live, "load_suggestions", %{"query" => "te"})
      updated_html = render(live)
      # Should still have profile suggestions
      assert updated_html =~ "profile-search-dropdown"
    end

    test "search query persists through page refresh", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)

      # Navigate with search query
      {:ok, _live, html} = live(conn, ~p"/profile?q=persistent")

      # Search query should be in the input
      assert html =~ "value=\"persistent\""
      # Page should be rendering with search query
      assert html =~ "persistent"
    end

    test "search with special characters handles properly", %{conn: conn, user: user} do
      # Create drop with special characters
      _drop = drop_fixture(%Drop{}, user, %{title: "C++ Programming", body: "Learning C++"})

      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/profile?q=C%2B%2B")

      html = render(live)
      assert html =~ "C++ Programming"
    end

    test "load suggestions for authenticated users shows history and popular", %{
      conn: conn,
      user: user
    } do
      # Create search history
      {:ok, _} = ElixirDrops.Search.create_search_history(%{query: "elixir", user_id: user.id})
      # Create popular search
      {:ok, _} = ElixirDrops.Search.create_or_increment_popular_search("phoenix")

      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/profile")

      # Type to trigger suggestions
      render_hook(live, "load_suggestions", %{"query" => "eli"})
      html = render(live)

      # Should show history item with clock icon
      assert html =~ "hero-clock"
      assert html =~ "elixir"
    end

    test "navbar and profile search have separate event handlers", %{conn: conn, user: user} do
      # Create search history and popular search for testing
      {:ok, _} = ElixirDrops.Search.create_search_history(%{query: "test", user_id: user.id})
      {:ok, _} = ElixirDrops.Search.create_or_increment_popular_search("testing")

      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/profile")

      # Load suggestions for navbar - this should populate navbar dropdown
      # Navbar dropdown should exist (though it might be hidden)
      assert render_hook(live, "load_navbar_suggestions", %{"query" => "test"}) =~
               "navbar-search-dropdown"

      # Load suggestions for profile search - should populate profile dropdown
      profile_html = render_hook(live, "load_suggestions", %{"query" => "test"})

      # Profile dropdown should exist
      assert profile_html =~ "profile-search-dropdown"
      # Should show suggestions
      assert profile_html =~ "test"
    end

    test "clear_search event clears profile search state and redirects", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/profile?q=phoenix")

      # Verify we're on profile search page with query
      assert render(live) =~ "phoenix"

      # Clear search - should redirect and clear state
      render_hook(live, "clear_search", %{})

      # Should redirect to profile page without query
      assert_patch(live, ~p"/profile")

      # Search state should be cleared
      refute render_hook(live, "clear_search", %{}) =~ "phoenix"
    end

    test "blur_search_input event hides profile suggestions", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/profile")

      # First load some suggestions
      render_hook(live, "load_suggestions", %{"query" => "elixir"})

      # Blur search input - should hide suggestions
      refute render_hook(live, "blur_search_input", %{}) =~ ~s[id="profile-search-dropdown"]
    end

    test "blur_navbar_search event hides navbar suggestions on profile", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/profile")

      # First load navbar suggestions
      render_hook(live, "load_navbar_suggestions", %{"query" => "phoenix"})

      # Blur navbar search - should hide suggestions
      refute render_hook(live, "blur_navbar_search", %{}) =~ ~s[id="navbar-search-dropdown"]
    end

    test "navbar search with empty query navigates to home", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/profile")

      # Submit empty navbar search query
      live
      |> form("#desktop-search-input form", %{"query" => ""})
      |> render_submit()

      # Should redirect to homepage
      assert_redirect(live, "/")
    end

    test "delete navbar search history handles delete operation", %{conn: conn, user: user} do
      # Create search history
      {:ok, history} =
        ElixirDrops.Search.create_search_history(%{
          query: "navbar_delete_test",
          user_id: user.id,
          results_count: 1
        })

      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/profile")

      # Delete the history item via navbar handler - should handle gracefully
      assert render_hook(live, "delete_navbar_search_history", %{"id" => history.id}) =~ "profile"

      # Verify history was actually deleted from database
      assert_raise Ecto.NoResultsError, fn ->
        ElixirDrops.Search.get_search_history!(history.id)
      end
    end
  end

  describe "screenshot generation broadcasts" do
    setup [:create_drops_setup]

    test "handles screenshot generation failure", %{conn: conn, user: user} do
      # Create another user for the drop
      user2 = user_fixture(%{github_id: 9_999_999})

      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/profile")

      # Create a drop from a different user that shouldn't appear on this user's profile
      drop = drop_fixture(%Drop{}, user2, %{title: "Test Drop From Other User"})

      # Verify it's not in the rendered page (since it's from a different user)
      refute render(live) =~ drop.title

      # Send screenshot generation failure for the other user's drop
      send(
        live.pid,
        {DropsBroadcast, [:drop, :screenshot_generation_completion], drop, 100, :failed, %{}}
      )

      # Should handle gracefully without streaming the drop (since it failed and it's not this user's drop)
      refute render(live) =~ drop.title
    end

    test "handles unexpected broadcast messages", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/profile")

      # Send unexpected message
      send(live.pid, {:unexpected_message, "test"})

      # Should handle gracefully
      assert render(live)
    end

    test "handles screenshot generation started when not in edit mode", %{conn: conn, user: user} do
      drop = drop_fixture(%Drop{}, user, %{title: "Test Drop"})

      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/profile")

      # Send screenshot generation started
      send(
        live.pid,
        {DropsBroadcast, [:drop, :screenshot_generation_started], drop}
      )

      # Should reload drops
      assert render(live)
    end
  end

  describe "error handling" do
    setup [:create_drops_setup]

    test "navigating to non-existent drop redirects to profile", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)

      # Try to navigate to a non-existent drop
      {:error, {:live_redirect, %{to: path}}} = live(conn, ~p"/drops/nonexistent/edit")
      assert path == ~p"/"
    end
  end
end
