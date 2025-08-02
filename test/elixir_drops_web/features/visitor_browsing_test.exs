defmodule ElixirDropsWeb.Features.VisitorBrowsingTest do
  @moduledoc """
  Domain-based feature tests for visitor browsing experience.

  Story 1: "As a visitor, I want to browse drops"

  Covers the complete visitor browsing domain including:
  - Homepage drop discovery and viewing
  - Drop card interactions and navigation  
  - Masonry layout display
  - Individual drop viewing experience
  - Infinite scroll content loading
  - Real-time drop notifications
  - Navigation between drops and homepage
  """

  use ElixirDropsWeb.FeatureCase, async: false

  import ElixirDrops.FeatureHelpers

  alias ElixirDrops.Drops.Drop

  @moduletag :feature

  describe "visitor discovers drops on homepage" do
    setup do
      user = user_fixture(%{github_id: 12_345, github_username: "creator"})

      # Create diverse drops for browsing
      elixir_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Elixir Pattern Matching",
          body: """
          def analyze(data) do
            case data do
              %{status: :ok, result: value} -> {:success, value}
              %{status: :error, reason: msg} -> {:failure, msg}
              _ -> {:unknown, data}
            end
          end
          """
        })

      phoenix_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Phoenix LiveView Counter",
          body: """
          defmodule MyApp.CounterLive do
            use Phoenix.LiveView
            
            def mount(_params, _session, socket) do
              {:ok, assign(socket, count: 0)}
            end
            
            def handle_event("increment", _params, socket) do
              {:noreply, assign(socket, count: socket.assigns.count + 1)}
            end
          end
          """
        })

      javascript_drop =
        drop_fixture(%Drop{}, user, %{
          title: "JavaScript Async Patterns",
          body: """
          async function fetchUserData(userId) {
            try {
              const response = await fetch(`/api/users/${userId}`);
              const userData = await response.json();
              return { success: true, data: userData };
            } catch (error) {
              return { success: false, error: error.message };
            }
          }
          """
        })

      %{
        user: user,
        elixir_drop: elixir_drop,
        phoenix_drop: phoenix_drop,
        javascript_drop: javascript_drop
      }
    end

    test "visitor sees drops in masonry layout on homepage", %{
      conn: conn,
      elixir_drop: elixir_drop,
      phoenix_drop: phoenix_drop,
      javascript_drop: javascript_drop
    } do
      conn
      |> visit(~p"/")
      # Verify page loads with drops displayed
      |> assert_has("main")
      |> assert_has("title", text: "ElixirDrops")

      # Check masonry layout displays all drops
      |> assert_has(".drop-card", text: elixir_drop.title)
      |> assert_has(".drop-card", text: phoenix_drop.title)
      |> assert_has(".drop-card", text: javascript_drop.title)

      # Verify drop cards show preview content
      |> assert_has(".drop-card", text: "Pattern Matching")
      |> assert_has(".drop-card", text: "LiveView Counter")
      |> assert_has(".drop-card", text: "Async Patterns")
    end

    test "visitor can click drop card to view full code", %{
      conn: conn,
      elixir_drop: elixir_drop
    } do
      conn
      |> visit(~p"/")
      # Click on the Elixir drop card
      |> click(".drop-card", text: elixir_drop.title)
      # Should navigate to drop view page
      |> assert_path("/drops/#{elixir_drop.short_id}")
      |> assert_has("h1", text: elixir_drop.title)

      # Verify full code is displayed with syntax highlighting
      |> assert_has("pre code", text: "def analyze(data)")
      |> assert_has("pre code", text: "case data do")
      |> assert_has(".highlight-elixir")
    end

    test "visitor sees author information and creation date", %{
      conn: conn,
      elixir_drop: elixir_drop,
      user: user
    } do
      conn
      |> visit("/d/#{elixir_drop.short_id}")
      # Verify author information is displayed
      |> assert_has("main", text: user.github_username)
      |> assert_has("main", text: "creator")

      # Verify relative time element is present
      |> assert_has("relative-time")
    end

    test "visitor can navigate back to homepage", %{
      conn: conn,
      elixir_drop: elixir_drop
    } do
      conn
      |> visit("/d/#{elixir_drop.short_id}")
      |> assert_has("h1", text: elixir_drop.title)

      # Click logo or home link to return
      |> click("a[href='/']")
      |> assert_path("/")
      |> assert_has("main")
      |> assert_has(".drop-card")
    end

    test "invalid drop URLs redirect to homepage", %{conn: conn} do
      conn
      |> visit("/drops/nonexistent123")
      # Should redirect to homepage
      |> assert_path("/")
      |> assert_has("main")
    end
  end

  describe "visitor browses with infinite scroll" do
    setup do
      user = user_fixture(%{github_id: 67_890, github_username: "prolific_coder"})

      # Create 25 drops for infinite scroll testing
      drops =
        for i <- 1..25 do
          drop_fixture(%Drop{}, user, %{
            title: "Code Drop #{i}",
            body: """
            def function_#{i}() do
              # This is code drop number #{i}
              :drop_#{i}
            end
            """
          })
        end

      %{user: user, drops: drops}
    end

    test "visitor can scroll to load more drops", %{conn: conn} do
      conn
      |> visit(~p"/")
      |> assert_has("main", text: "Code Drop 1")
      # Initial page should show first batch (typically 20 drops)
      |> assert_has(".drop-card")
      |> assert_element(".drop-card", count: 20)

      # Scroll down to trigger infinite scroll loading
      |> scroll_down(800)
      # Allow time for lazy loading
      |> wait_for(time: 2)
      # More drops should now be visible
      |> assert_element(".drop-card", minimum: 21)

      # Scroll more to load remaining drops
      |> scroll_down(800)
      |> wait_for(time: 2)
      # Should eventually show all 25 drops
      |> assert_has("main", text: "Code Drop 25")
      |> assert_element(".drop-card", count: 25)
    end

    test "visitor sees loading indicator during scroll", %{conn: conn} do
      conn
      |> visit(~p"/")
      |> assert_has("main")
      # Initially no loading indicator
      |> refute_has(".loading-indicator")

      # Scroll aggressively to trigger loading
      |> scroll_down(1200)
      |> wait_for_element(".loading-indicator", timeout: 5000)
      # Loading indicator should appear during content fetch
      |> assert_has(".loading-indicator")

      # Wait for loading to complete
      |> wait_for(time: 3)
      # Loading indicator should disappear when content loads
      |> refute_has(".loading-indicator")
      # More content should be loaded
      |> assert_element(".drop-card", minimum: 21)
    end

    test "infinite scroll handles last page gracefully", %{conn: conn} do
      conn
      |> visit(~p"/")
      # Load all drops by scrolling multiple times
      |> scroll_down(800)
      |> wait_for(time: 2)
      |> scroll_down(800)
      |> wait_for(time: 2)
      |> scroll_down(800)
      |> wait_for(time: 2)

      # Should show all 25 drops
      |> assert_element(".drop-card", count: 25)
      |> assert_has("main", text: "Code Drop 25")

      # Additional scrolling shouldn't break anything
      |> scroll_down(400)
      |> wait_for(time: 1)
      # Still should have exactly 25 drops
      |> assert_element(".drop-card", count: 25)
    end
  end

  describe "visitor sees real-time drop notifications" do
    setup do
      existing_user = user_fixture(%{github_id: 11_111, github_username: "existing"})

      existing_drop =
        drop_fixture(%Drop{}, existing_user, %{
          title: "Existing Drop",
          body: "def existing, do: :ok"
        })

      %{existing_user: existing_user, existing_drop: existing_drop}
    end

    test "visitor sees new drops notification when others post", %{conn: conn} do
      conn
      |> visit(~p"/")
      |> assert_has("main", text: "Existing Drop")

      # Simulate new drop being created by another user
      # (In real app, this would trigger LiveView broadcast)
      new_user = user_fixture(%{github_id: 22_222, github_username: "newcomer"})

      _new_drop =
        drop_fixture(%Drop{}, new_user, %{
          title: "Brand New Drop",
          body: "def brand_new, do: :fresh"
        })

      # Wait for real-time notification to appear
      conn
      |> wait_for_element(".new-drops-notification", timeout: 5000)
      |> assert_has(".new-drops-notification")
      |> assert_has(".new-drops-notification", text: "New Drops")
    end

    test "visitor can click notification to refresh list", %{conn: conn} do
      visit(conn, ~p"/")

      # Create new drop while visitor is on page
      new_user = user_fixture(%{github_id: 33_333, github_username: "realtime"})

      new_drop =
        drop_fixture(%Drop{}, new_user, %{
          title: "Real-time Drop Update",
          body: "def realtime, do: :live"
        })

      # Wait for and click the notification
      conn
      |> wait_for_element(".new-drops-notification", timeout: 5000)
      |> click(".new-drops-notification")

      # List should refresh to show new drop
      |> wait_for(time: 2)
      |> assert_has("main", text: new_drop.title)
      |> assert_has(".drop-card", text: "Real-time Drop Update")

      # Notification should disappear after clicking
      |> refute_has(".new-drops-notification")
    end
  end

  describe "visitor navigation experience" do
    setup do
      user = user_fixture(%{github_id: 44_444, github_username: "navigator"})

      drop1 =
        drop_fixture(%Drop{}, user, %{
          title: "Navigation Test Drop 1",
          body: "def nav_test_1, do: :first"
        })

      drop2 =
        drop_fixture(%Drop{}, user, %{
          title: "Navigation Test Drop 2",
          body: "def nav_test_2, do: :second"
        })

      %{user: user, drop1: drop1, drop2: drop2}
    end

    test "visitor can navigate between multiple drops", %{
      conn: conn,
      drop1: drop1,
      drop2: drop2
    } do
      conn
      |> visit(~p"/")
      # Navigate to first drop
      |> click(".drop-card", text: drop1.title)
      |> assert_path("/drops/#{drop1.short_id}")
      |> assert_has("h1", text: drop1.title)

      # Go back to homepage
      |> click("a[href='/']")
      |> assert_path("/")

      # Navigate to second drop
      |> click(".drop-card", text: drop2.title)
      |> assert_path("/drops/#{drop2.short_id}")
      |> assert_has("h1", text: drop2.title)

      # Browser back navigation should work
      |> visit("javascript:history.back()")
      |> assert_path("/")
    end

    test "visitor sees consistent navigation elements", %{conn: conn, drop1: drop1} do
      conn
      |> visit(~p"/")
      # Logo should be clickable from homepage
      |> assert_has("a[href='/']")
      |> visit("/d/#{drop1.short_id}")
      # Logo should still be clickable from drop page
      |> assert_has("a[href='/']")

      # Navigation should be consistent across pages
      |> assert_has("nav")
    end
  end

  describe "visitor search functionality" do
    setup do
      user = user_fixture(%{github_id: 55_555, github_username: "searchable"})

      elixir_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Advanced Elixir Techniques",
          body: "def advanced_elixir, do: :techniques"
        })

      phoenix_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Phoenix LiveView Magic",
          body: "def phoenix_magic, do: :liveview"
        })

      %{user: user, elixir_drop: elixir_drop, phoenix_drop: phoenix_drop}
    end

    test "visitor can search drops using navbar search", %{
      conn: conn,
      elixir_drop: elixir_drop
    } do
      conn
      |> visit(~p"/")
      |> assert_has("input[placeholder*='Search']")

      # Search for Elixir drops
      |> fill_in("Search drops", with: "Elixir")
      |> press_key("Enter")

      # Should show search results
      |> assert_url_contains("?q=Elixir")
      |> assert_has("main", text: elixir_drop.title)
    end

    test "visitor sees popular search suggestions", %{conn: conn} do
      # Create some popular searches (would be done by system)
      # For test, we'll focus on the UI behavior

      conn
      |> visit(~p"/")
      # Focus on search input
      |> focus_search_input()
      |> wait_for_element("#navbar-search-dropdown", timeout: 3000)

      # Should show popular suggestions for unauthenticated users
      |> assert_has("#navbar-search-dropdown")
      # Should NOT show delete buttons for visitors
      |> refute_has("button[phx-click='delete_navbar_search_history']")
    end

    test "visitor search persists in URL and can be cleared", %{
      conn: conn,
      elixir_drop: elixir_drop,
      phoenix_drop: phoenix_drop
    } do
      conn
      |> visit(~p"/?q=Phoenix")
      # Search results should be filtered
      |> assert_has("main", text: phoenix_drop.title)
      |> refute_has("main", text: elixir_drop.title)

      # Clear search by visiting homepage
      |> visit(~p"/")
      # Should show all drops again
      |> assert_has("main", text: elixir_drop.title)
      |> assert_has("main", text: phoenix_drop.title)
    end
  end
end
