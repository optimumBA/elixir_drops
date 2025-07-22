defmodule ElixirDropsWeb.DropLiveTest do
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
        Drops.update_drop(drop1, user, %{screenshot: %{status: :pending}})

      {:ok, failed_drop} = Drops.update_drop(drop2, user, %{screenshot: %{status: :failed}})

      {:ok, completed_drop} =
        Drops.update_drop(drop, user, %{screenshot: %{status: :completed}})

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
      {:ok, skipped_drop} = Drops.update_drop(drop, user, %{screenshot: %{status: :skipped}})

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
          body: "Drop body without code block",
          screenshot: %{
            status: :completed,
            url: "http://example.com/screenshot.png"
          },
          title: "New Drop title"
        })

      assert has_element?(live, "#new-drops-indicator")

      assert live
             |> element("#new-drops-indicator")
             |> render_click() =~ drop.title

      assert has_element?(live, "#drop-#{drop.id}")
    end

    test "user sees drop automatically when screenshot generation completes",
         %{
           conn: conn,
           user: user
         } do
      Drops.subscribe()

      {:ok, live, _html} = live(conn, ~p"/")

      refute has_element?(live, "#new-drops-indicator")

      {:ok, drop} =
        Drops.create_drop(%Drop{}, user, %{
          body:
            "Drop body ```elixir\ndefmodule Test do\n  def hello do\n    :world\n  end\nend\n```",
          screenshot: %{status: :pending},
          title: "New Drop title"
        })

      # Drop with pending screenshot should not appear yet
      refute has_element?(live, "#drop-#{drop.id}")

      {:ok, updated_drop} =
        Drops.update_drop(drop, user, %{
          screenshot: %{status: :completed, url: "http://example.com/screenshot.png"}
        })

      DropsBroadcast.broadcast_drop_screenshot_completion(
        updated_drop,
        100,
        :completed,
        %{action: "new"}
      )

      Process.sleep(100)

      assert has_element?(live, "#new-drops-indicator")

      assert live
             |> element("#new-drops-indicator")
             |> render_click() =~ drop.title

      assert has_element?(live, "#drop-#{drop.id}")
    end

    test "user does not see an indicator when an existing drop's screenshot is regenerated",
         %{
           conn: conn,
           user: user
         } do
      {:ok, drop} =
        Drops.create_drop(%Drop{}, user, %{
          body:
            "Drop body with code ```elixir\ndefmodule Test do\n  def hello do\n    :world\n  end\nend\n```",
          screenshot: %{status: :completed, url: "http://example.com/screenshot.png"},
          title: "Existing Drop title"
        })

      Drops.subscribe()

      {:ok, live, _html} = live(conn, ~p"/")

      assert has_element?(live, "#drop-#{drop.id}")

      refute has_element?(live, "#new-drops-indicator")

      {:ok, updated_drop} =
        Drops.update_drop(drop, user, %{
          screenshot: %{status: :pending, url: nil}
        })

      {:ok, completed_drop} =
        Drops.update_drop(updated_drop, user, %{
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
      _drops = create_multiple_drops(user, 35)

      {:ok, live, html} = live(conn, ~p"/")

      # First page should have Drop title 35 (newest) but not Drop title 20
      assert html =~ "Drop title 35"
      # Should have the 15th drop (oldest on first page)
      assert html =~ "Drop title 21"
      # Should NOT have the 16th drop
      refute html =~ "Drop title 20"
      # Should NOT have the oldest drop
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

    test "viewport update event is handled", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      assert render_hook(live, "update-viewport", %{"width" => 375, "height" => 667}) =~ "drops"
      assert render_hook(live, "update-viewport", %{"width" => 1920, "height" => 1080}) =~ "drops"
    end

    test "load-more with layout_complete flag works", %{conn: conn, user: user} do
      create_multiple_drops(user, 20)
      {:ok, live, _html} = live(conn, ~p"/")

      assert render_hook(live, "load-more", %{"layout_complete" => true}) != ""
    end

    test "load-more-complete event is handled", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      assert render_hook(live, "load-more-complete", %{}) =~ "drops"
    end

    test "screenshot generation started broadcast doesn't change page state", %{
      conn: conn,
      user: user
    } do
      Drops.subscribe()

      {:ok, live, _html} = live(conn, ~p"/")

      refute has_element?(live, "#new-drops-indicator")

      {:ok, drop} =
        Drops.create_drop(%Drop{}, user, %{
          body:
            "Drop body with code block ```elixir\ndefmodule Test do\n  def hello do\n    :world\n  end\nend\n```",
          screenshot: %{status: :pending},
          title: "New Drop with Pending Screenshot"
        })

      refute has_element?(live, "#drop-#{drop.id}")
      refute has_element?(live, "#new-drops-indicator")

      DropsBroadcast.broadcast_drop_screenshot_started(drop)

      Process.sleep(100)
      render(live)

      refute has_element?(live, "#new-drops-indicator")
      refute has_element?(live, "#drop-#{drop.id}")
    end
  end

  describe "/d/:short_id" do
    setup [:create_drops_setup]

    test "user can view a drop", %{conn: conn, user: user} do
      drop =
        drop_fixture(%Drop{}, user, %{
          title: "Drop title",
          body: "Drop body text...",
          screenshot: %{
            meta: %{status: :completed, url: "https://example.com/screenshot.png"},
            internal: %{status: :completed, url: "https://example.com/screenshot.png"}
          }
        })

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

      {:ok, updated_drop} =
        Drops.update_drop(drop, user, %{
          screenshot: %{
            meta: %{status: :completed, url: "https://example.com/screenshot.png"},
            internal: %{status: :completed, url: "https://example.com/screenshot.png"}
          }
        })

      {:ok, _live, html} = live(conn, ~p"/d/#{updated_drop.short_id}")

      refute html =~ ~r|<div>"Some malicious code"</div>|
      assert html =~ "Drop with script"
      assert html =~ "User drop with JS"
    end

    test "rendered HTML includes SEO meta tags for drop", %{
      conn: conn,
      drop: drop,
      user: user
    } do
      {:ok, _live, html} = live(conn, ~p"/d/#{drop.short_id}")

      assert html =~ "<meta name=\"twitter:card\" content=\"summary_large_image\"/>"
      assert html =~ "<meta name=\"twitter:description\" content=\"#{drop.title}...\"/>"

      assert html =~
               "<meta name=\"twitter:image\" content=\"#{url(~p"/images/seo_default_image.png")}\"/>"

      assert html =~ "<meta name=\"twitter:site\" content=\"@optimumBA\"/>"

      assert html =~
               "<meta name=\"twitter:url\" content=\"#{url(~p"/d/#{drop.short_id}")}\"/>"

      assert html =~
               "<meta property=\"description\" content=\"#{drop.title}...\"/>"

      assert html =~
               "<meta property=\"og:description\" content=\"#{drop.title}...\"/>"

      assert html =~
               "<meta property=\"og:image\" content=\"#{url(~p"/images/seo_default_image.png")}\"/>"

      assert html =~ "<meta property=\"og:title\" content=\"Elixir Drops\"/>"
      assert html =~ "<meta property=\"og:type\" content=\"article\"/>"

      assert html =~
               "<meta property=\"og:url\" content=\"#{url(~p"/d/#{drop.short_id}")}\"/>"

      {:ok, _updated_drop} =
        Drops.update_drop(drop, user, %{
          screenshot: %{
            internal_url: "http://image.com/drop-internal-image-latest-#{drop.id}.png",
            meta_url: "http://image.com/drop-meta-image-latest-#{drop.id}.png",
            status: :completed
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
        title: "[In this drop](/good_drop) we discussed stuff"
      }

      drop = drop_fixture(%Drop{}, user, drop_attributes)

      {:ok, updated_drop} =
        Drops.update_drop(drop, user, %{
          screenshot: %{
            meta: %{status: :completed, url: "https://example.com/screenshot.png"},
            internal: %{status: :completed, url: "https://example.com/screenshot.png"}
          }
        })

      {:ok, _live, html} = live(conn, ~p"/d/#{updated_drop.short_id}")

      assert html =~
               "<meta property=\"description\" content=\"In this drop we discussed stuff...\"/>"

      assert html =~
               "<meta property=\"og:description\" content=\"In this drop we discussed stuff...\"/>"

      assert html =~
               "<meta name=\"twitter:description\" content=\"In this drop we discussed stuff...\"/>"
    end

    test "rendered HTML includes structured data for drop", %{
      conn: conn,
      drop: drop
    } do
      {:ok, _live, html} = live(conn, ~p"/d/#{drop.short_id}")

      assert html =~ ~s(<script type="application/ld+json">)
      assert html =~ ~s(</script>)

      json_ld =
        html
        |> String.split(~s(<script type="application/ld+json">))
        |> Enum.at(1)
        |> String.split(~s(</script>))
        |> Enum.at(0)
        |> String.trim()

      assert {:ok, decoded} = Jason.decode(json_ld)
      assert decoded["@context"] == "https://schema.org"
      assert decoded["@type"] == "Article"
      assert decoded["headline"] == drop.title
      assert decoded["articleBody"] == drop.body
      assert decoded["url"] == "https://elixirdrops.net/d/#{drop.short_id}"
      assert decoded["author"]["@type"] == "Person"
      assert decoded["author"]["name"] == drop.user.name
      assert decoded["author"]["url"] == "https://github.com/#{drop.user.github_username}"
      assert decoded["author"]["image"] == drop.user.avatar
      assert decoded["publisher"]["@type"] == "Organization"
      assert decoded["publisher"]["name"] == "ElixirDrops"
      assert decoded["publisher"]["logo"]["@type"] == "ImageObject"
      assert decoded["publisher"]["logo"]["url"] == "https://elixirdrops.net/images/logo.png"
      assert decoded["datePublished"] == NaiveDateTime.to_iso8601(drop.inserted_at)
      assert decoded["dateModified"] == NaiveDateTime.to_iso8601(drop.updated_at)
      assert decoded["mainEntityOfPage"]["@type"] == "WebPage"
      assert decoded["mainEntityOfPage"]["@id"] == "https://elixirdrops.net/d/#{drop.short_id}"
      assert is_binary(decoded["description"])
      assert String.length(decoded["description"]) <= 160
      assert is_list(decoded["keywords"])
    end

    test "structured data includes screenshot when available", %{
      conn: conn,
      drop: drop,
      user: user
    } do
      {:ok, updated_drop} =
        Drops.update_drop(drop, user, %{
          screenshot: %{
            internal_url: "http://image.com/drop-internal-image-latest-#{drop.id}.png",
            meta_url: "http://image.com/drop-meta-image-latest-#{drop.id}.png",
            status: :completed
          }
        })

      {:ok, _live, html} = live(conn, ~p"/d/#{updated_drop.short_id}")

      json_ld =
        html
        |> String.split(~s(<script type="application/ld+json">))
        |> Enum.at(1)
        |> String.split(~s(</script>))
        |> Enum.at(0)
        |> String.trim()

      assert {:ok, decoded} = Jason.decode(json_ld)
      assert length(decoded["image"]) == 1
      image = List.first(decoded["image"])
      assert image["@type"] == "ImageObject"
      assert image["url"] == "http://image.com/drop-meta-image-latest-#{drop.id}.png"
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

  describe "drop card text processing" do
    setup [:create_drops_setup]

    test "preserves underscores in drop descriptions", %{conn: conn, user: user} do
      _drop =
        drop_fixture(%Drop{}, user, %{
          title: "Test Drop",
          body: "optimum_gen_infra version 0.2.0 was released with cursor_rules support"
        })

      {:ok, _live, html} =
        conn
        |> sign_in_user(user)
        |> live(~p"/")

      assert html =~ "optimum_gen_infra version 0.2.0"
      assert html =~ "cursor_rules"
    end

    test "strips markdown syntax from drop descriptions", %{conn: conn, user: user} do
      _drop =
        drop_fixture(%Drop{}, user, %{
          title: "Test Drop",
          body: "Check out [this link](https://example.com) and **bold text** with *italic*"
        })

      {:ok, _live, html} =
        conn
        |> sign_in_user(user)
        |> live(~p"/")

      assert html =~ "Check out this link and bold text with italic"
      refute html =~ "[this link]"
      refute html =~ "**bold text**"
      refute html =~ "*italic*"
    end

    test "truncates long descriptions to 150 characters", %{conn: conn, user: user} do
      long_text = String.duplicate("a", 200)

      _drop =
        drop_fixture(%Drop{}, user, %{
          title: "Test Drop",
          body: long_text
        })

      {:ok, _live, html} =
        conn
        |> sign_in_user(user)
        |> live(~p"/")

      assert html =~ "Test Drop"
      assert html =~ String.slice(long_text, 0, 100)
      assert html =~ "..."
      refute html =~ long_text
    end

    test "truncates before code block when it appears early", %{conn: conn, user: user} do
      _drop =
        drop_fixture(%Drop{}, user, %{
          title: "Test Drop",
          body: "Here is some text before code:\n```\ncode block content\n```\nmore text after"
        })

      {:ok, _live, html} =
        conn
        |> sign_in_user(user)
        |> live(~p"/")

      assert html =~ "Here is some text before code:..."
      refute html =~ "```"
      refute html =~ "code block content"
    end

    test "removes emphasis but preserves underscores in words", %{conn: conn, user: user} do
      _drop =
        drop_fixture(%Drop{}, user, %{
          title: "Test Drop",
          body: "This has _emphasized text_ but preserves snake_case_names"
        })

      {:ok, _live, html} =
        conn
        |> sign_in_user(user)
        |> live(~p"/")

      assert html =~ "This has emphasized text but preserves snake_case_names"
      refute html =~ "_emphasized text_"
    end

    test "handles multiple markdown elements", %{conn: conn, user: user} do
      _drop =
        drop_fixture(%Drop{}, user, %{
          title: "Test Drop",
          body: "# Header\n\nSome **bold** and `inline code` with > quote"
        })

      {:ok, _live, html} =
        conn
        |> sign_in_user(user)
        |> live(~p"/")

      assert html =~ "Test Drop"
      assert html =~ "Header"
      assert html =~ "Some bold and inline code with"
      refute html =~ "# Header"
      refute html =~ "**"
      refute html =~ "`"
    end

    test "search submit should not crash LiveView", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      # This should not crash the LiveView - using direct event instead of form
      result = render_hook(live, "search_submit", %{"query" => "phoenix"})

      # Should return HTML and not crash
      assert result =~ "ElixirDrops"
    end

    test "search suggestions should work for unauthenticated users", %{conn: conn} do
      import ElixirDrops.SearchFixtures

      # Create some popular searches
      popular_search_fixture(%{query: "phoenix tutorial", search_count: 100})
      popular_search_fixture(%{query: "phoenix deployment", search_count: 80})

      {:ok, live, _html} = live(conn, ~p"/")

      # Trigger load_suggestions event with "phoe" prefix - should show popular suggestions
      result1 = render_hook(live, "load_suggestions", %{"query" => "phoe"})
      assert result1 =~ "ElixirDrops"

      # Should handle short queries (less than 2 characters) without crashing
      result2 = render_hook(live, "load_suggestions", %{"query" => "p"})
      assert result2 =~ "ElixirDrops"

      # Should handle empty query without crashing
      result3 = render_hook(live, "load_suggestions", %{"query" => ""})
      assert result3 =~ "ElixirDrops"
    end

    test "search suggestions should work for authenticated users", %{conn: conn, user: user} do
      import ElixirDrops.SearchFixtures

      # Create some search history for the user
      search_history_fixture(%{user_id: user.id, query: "phoenix liveview"})
      search_history_fixture(%{user_id: user.id, query: "phoenix websocket"})

      # Create some popular searches
      popular_search_fixture(%{query: "phoenix tutorial", search_count: 100})
      popular_search_fixture(%{query: "phoenix deployment", search_count: 80})

      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/")

      # Trigger load_suggestions event with "phoe" prefix - should not crash
      result1 = render_hook(live, "load_suggestions", %{"query" => "phoe"})

      # Should return HTML and not crash
      assert result1 =~ "ElixirDrops"

      # Should handle short queries (less than 2 characters) without crashing
      result2 = render_hook(live, "load_suggestions", %{"query" => "p"})
      assert result2 =~ "ElixirDrops"

      # Should handle empty query without crashing
      result3 = render_hook(live, "load_suggestions", %{"query" => ""})
      assert result3 =~ "ElixirDrops"
    end

    test "search results should return matching drops", %{conn: conn, user: user} do
      # Create drops with specific content for search testing
      phoenix_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Phoenix LiveView Tutorial",
          body: "Learn how to build real-time applications with Phoenix LiveView"
        })

      elixir_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Elixir Pattern Matching",
          body: "Understanding pattern matching in Elixir programming language"
        })

      rust_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Rust Memory Safety",
          body: "Exploring memory safety features in Rust programming"
        })

      # Update drops to have completed screenshot status so they appear in search
      {:ok, _} = Drops.update_drop(phoenix_drop, user, %{screenshot: %{status: :completed}})
      {:ok, _} = Drops.update_drop(elixir_drop, user, %{screenshot: %{status: :completed}})
      {:ok, _} = Drops.update_drop(rust_drop, user, %{screenshot: %{status: :completed}})

      {:ok, live, _html} = live(conn, ~p"/")

      # Search for "phoenix" should return the phoenix drop but not others
      submit_result = render_hook(live, "search_submit", %{"query" => "phoenix"})
      assert submit_result =~ "ElixirDrops"

      # Navigate to search results page
      {:ok, _live, phoenix_html} = live(conn, ~p"/?q=phoenix")

      # Should find the phoenix drop
      assert phoenix_html =~ "Phoenix LiveView Tutorial"
      assert phoenix_html =~ "Learn how to build real-time applications"

      # Should not find unrelated drops
      refute phoenix_html =~ "Rust Memory Safety"

      # Search for "elixir" should return the elixir drop
      {:ok, _live, elixir_html} = live(conn, ~p"/?q=elixir")

      # Should find the elixir drop
      assert elixir_html =~ "Elixir Pattern Matching"
      assert elixir_html =~ "Understanding pattern matching"

      # Should not find unrelated drops
      refute elixir_html =~ "Rust Memory Safety"

      # Search for non-existent term should return no results
      {:ok, _live, javascript_html} = live(conn, ~p"/?q=javascript")

      # Should not find any of our test drops
      refute javascript_html =~ "Phoenix LiveView Tutorial"
      refute javascript_html =~ "Elixir Pattern Matching"
      refute javascript_html =~ "Rust Memory Safety"
    end

    test "close_search_overlay event hides search suggestions", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      render_hook(live, "close_search_overlay", %{})

      html = render(live)
      refute html =~ "search-suggestions"
    end

    test "delete_search_history removes history item for authenticated users", %{
      conn: conn,
      user: user
    } do
      # Create search history
      history = search_history_fixture(%{user_id: user.id, query: "phoenix test"})

      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/")

      render_hook(live, "delete_search_history", %{"id" => history.id})

      # Verify the history was deleted
      assert_raise Ecto.NoResultsError, fn ->
        ElixirDrops.Search.get_search_history!(history.id)
      end
    end

    test "load_suggestions with nil query shows no suggestions", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      result = render_hook(live, "load_suggestions", %{"query" => nil})
      refute result =~ "search-suggestions"
    end

    test "load_suggestions with empty query shows no suggestions", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      result = render_hook(live, "load_suggestions", %{"query" => ""})
      refute result =~ "search-suggestions"
    end

    test "load_suggestions with single character shows no suggestions", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      result = render_hook(live, "load_suggestions", %{"query" => "a"})
      refute result =~ "search-suggestions"
    end

    test "load_suggestions with non-binary query shows no suggestions", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      # Send a non-binary value for query
      result = render_hook(live, "load_suggestions", %{"query" => 123})
      refute result =~ "search-suggestions"
    end

    test "search with non-existent query shows no results message", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      render_hook(live, "search_submit", %{"query" => "nonexistentquery123"})

      {:ok, _search_view, search_html} = live(conn, ~p"/?q=nonexistentquery123")
      assert search_html =~ "Sorry we couldn&#39;t find any results for this search."
    end

    test "load_navbar_suggestions with non-binary query clears suggestions", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      # First load some suggestions
      render_hook(live, "load_navbar_suggestions", %{"query" => "elixir"})

      # Then send non-binary query
      result = render_hook(live, "load_navbar_suggestions", %{"query" => nil})
      refute result =~ "search-suggestions"
    end

    test "screenshot generation completion with non-new action is ignored", %{
      conn: conn,
      user: user
    } do
      {:ok, live, _html} = live(conn, ~p"/")

      drop = drop_fixture(%Drop{}, user, %{title: "Test Drop"})

      # Send screenshot completion with action other than "new"
      send(
        live.pid,
        {DropsBroadcast, [:drop, :screenshot_generation_completion], drop, 100, :completed,
         %{action: "update"}}
      )

      # View should not change or show new drops indicator
      refute render(live) =~ "new-drops-indicator"
    end

    test "navbar search always navigates to homepage", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/")

      # Submit navbar search
      live
      |> form("#desktop-search-input form", %{
        "query" => "test"
      })
      |> render_submit()

      # Check that URL was updated (this triggers a handle_params call)
      assert_patch(live, ~p"/?q=test")
    end

    test "navbar search suggestions work independently from main search", %{
      conn: conn,
      user: user
    } do
      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/")

      # Test navbar suggestions
      navbar_html = render_hook(live, "load_navbar_suggestions", %{"query" => "eli"})
      # Check if navbar dropdown is shown (it would have the hidden class removed)
      assert navbar_html =~ "navbar-search-dropdown"

      # Test regular suggestions
      regular_html = render_hook(live, "load_suggestions", %{"query" => "pho"})
      # Both can have suggestions shown independently
      assert regular_html =~ "search-dropdown" or regular_html =~ "navbar-search-dropdown"
    end

    test "delete navbar search history updates suggestions", %{conn: conn, user: user} do
      # Create search history
      {:ok, history} =
        ElixirDrops.Search.create_search_history(%{query: "navbar delete", user_id: user.id})

      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/")

      # Focus navbar search to show suggestions
      render_hook(live, "focus_navbar_search", %{})
      initial_html = render(live)
      assert initial_html =~ "navbar delete"

      # Delete the history item
      render_hook(live, "delete_navbar_search_history", %{"id" => history.id})

      # Re-focus to get updated suggestions
      render_hook(live, "focus_navbar_search", %{})
      updated_html = render(live)

      # Should no longer show the deleted item
      refute updated_html =~ "navbar delete"
    end

    test "empty navbar search stays on current page", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      # Submit empty navbar search
      live
      |> form("#desktop-search-input form", %{"query" => ""})
      |> render_submit()

      # Should stay on homepage without query (same URL, no patch)
      # When search is empty, it navigates to "/" which is the same page
      assert_patch(live, ~p"/")
    end

    test "mobile search overlay behavior", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)
      {:ok, _live, html} = live(conn, ~p"/")

      # Mobile search overlay should exist but be hidden
      assert html =~ "search-overlay"
      assert html =~ "hidden fixed"
      assert html =~ "z-50"
    end

    test "search suggestions render with correct icons", %{conn: conn, user: user} do
      # Create history and popular searches
      {:ok, _} =
        ElixirDrops.Search.create_search_history(%{query: "history item", user_id: user.id})

      {:ok, _} = ElixirDrops.Search.create_or_increment_popular_search("popular item")

      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/")

      # Focus to show initial suggestions
      render_hook(live, "focus_search_input", %{})
      html = render(live)

      # History items should have clock icon
      assert html =~ "hero-clock"
      assert html =~ "history item"

      # Popular items should have magnifying glass icon
      assert html =~ "hero-magnifying-glass"
    end

    test "suggestions update as user types", %{conn: conn, user: user} do
      # Create various search items - need results_count for history
      {:ok, _} =
        ElixirDrops.Search.create_search_history(%{
          query: "elixir",
          user_id: user.id,
          results_count: 10
        })

      {:ok, _} =
        ElixirDrops.Search.create_search_history(%{
          query: "ecto",
          user_id: user.id,
          results_count: 5
        })

      {:ok, _} =
        ElixirDrops.Search.create_search_history(%{
          query: "phoenix",
          user_id: user.id,
          results_count: 8
        })

      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/")

      # Type "el" - should show elixir (need at least 2 chars)
      render_hook(live, "load_suggestions", %{"query" => "el"})
      html = render(live)

      # Check that elixir is shown in suggestions
      assert html =~ "elixir"

      # Type "ph" - should show phoenix
      render_hook(live, "load_suggestions", %{"query" => "ph"})
      updated_html = render(live)

      assert updated_html =~ "phoenix"
    end

    test "search history is tracked for authenticated users", %{conn: conn, user: user} do
      conn = sign_in_user(conn, user)
      {:ok, live, _html} = live(conn, ~p"/")

      # Perform a search
      render_hook(live, "search_submit", %{"query" => "tracked search"})

      # Verify history was created
      histories = ElixirDrops.Search.get_user_search_history(user.id)
      queries = Enum.map(histories, & &1.query)
      assert "tracked search" in queries
    end

    test "unauthenticated users see only popular searches", %{conn: conn} do
      # Create popular searches
      {:ok, _} = ElixirDrops.Search.create_or_increment_popular_search("popular one")
      {:ok, _} = ElixirDrops.Search.create_or_increment_popular_search("popular two")

      {:ok, live, _html} = live(conn, ~p"/")

      # Focus should show popular searches
      render_hook(live, "focus_search_input", %{})
      html = render(live)

      # Should only show popular searches, no history
      assert html =~ "popular one"
      assert html =~ "popular two"
      # No clock icons for history
      refute html =~ "hero-clock"
    end

    test "clear_search event clears search state and redirects to home", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/?q=phoenix")

      # Verify we're on search page with query
      assert render(live) =~ "phoenix"

      # Clear search - should redirect and clear state
      render_hook(live, "clear_search", %{})

      # Should redirect to home page
      assert_patch(live, ~p"/")

      # Search state should be cleared
      refute render_hook(live, "clear_search", %{}) =~ "phoenix"
    end

    test "blur_search_input event hides suggestions", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      # First load some suggestions
      render_hook(live, "load_suggestions", %{"query" => "elixir"})

      # Blur search input - should hide suggestions
      blur_html = render_hook(live, "blur_search_input", %{})
      refute blur_html =~ ~s[id="mobile-search-dropdown"]
      refute blur_html =~ ~s[id="navbar-search-dropdown"]
    end

    test "blur_navbar_search event hides navbar suggestions", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      # First load navbar suggestions
      render_hook(live, "load_navbar_suggestions", %{"query" => "phoenix"})

      # Blur navbar search - should hide suggestions
      blur_html = render_hook(live, "blur_navbar_search", %{})
      refute blur_html =~ ~s[id="navbar-search-dropdown"]
    end

    test "navbar suggestions with query less than 2 characters shows no suggestions", %{
      conn: conn
    } do
      {:ok, live, _html} = live(conn, ~p"/")

      # Test with single character query
      single_char_html = render_hook(live, "load_navbar_suggestions", %{"query" => "a"})
      refute single_char_html =~ ~s[id="navbar-search-dropdown"]

      # Test with empty query
      empty_query_html = render_hook(live, "load_navbar_suggestions", %{"query" => ""})
      refute empty_query_html =~ ~s[id="navbar-search-dropdown"]
    end
  end
end
