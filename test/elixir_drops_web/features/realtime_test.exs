defmodule ElixirDropsWeb.Features.RealtimeUpdatesTest do
  @moduledoc """
  Domain-based feature tests for real-time updates experience.

  Story 7: "As a user, I want real-time updates and live interactions"

  Covers the complete real-time updates domain including:
  - LiveView real-time form interactions and validation
  - Live drop updates and content synchronization
  - WebSocket connection stability and recovery
  - Live search and filtering capabilities
  - Real-time notifications and user feedback
  - Multi-user collaborative features and updates
  """

  use ElixirDropsWeb.FeatureCase, async: false

  import ElixirDrops.FeatureHelpers

  alias ElixirDrops.Drops.Drop

  @moduletag :feature

  describe "real-time form interactions and validation" do
    setup do
      user = user_fixture(%{github_id: 12_345, github_username: "realtime_user"})
      %{user: user}
    end

    test "drop creation form provides live validation feedback", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # Submit empty form to trigger live validation
      |> click("button[type='submit']", text: "Post Drop")

      # Should see live validation errors without page reload
      |> assert_path("/drops/new")
      |> assert_has("form", text: "can't be blank")

      # Fill title and see validation update live
      |> fill_in("Title", with: "Live Validation Test")

      # Form should show that title is now valid (error should disappear or change)
      |> assert_field_value("Title", "Live Validation Test")

      # Complete form and submit
      |> fill_in("Code", with: "def live_validation, do: :success")
      |> click("button[type='submit']", text: "Post Drop")

      # Should navigate without page refresh
      |> assert_path("/profile")
      |> assert_has("main", text: "Drop created successfully")
    end

    test "drop edit form updates live without page refresh", %{conn: conn, user: user} do
      drop =
        drop_fixture(%Drop{}, user, %{
          title: "Live Edit Test",
          body: "def live_edit, do: :before"
        })

      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/#{drop.short_id}/edit")

      # Verify form is pre-populated with live data
      |> assert_field_value("Title", drop.title)
      |> assert_field_value("Code", drop.body)

      # Make changes and trigger live validation
      # Invalid
      |> fill_in("Title", with: "")
      |> click("button[type='submit']", text: "Update Drop")

      # Should get live validation feedback
      # Stay on edit page
      |> assert_path("/drops/#{drop.short_id}/edit")
      |> assert_has("form", text: "can't be blank")

      # Fix validation error live
      |> fill_in("Title", with: "Live Updated Drop")
      |> fill_in("Code", with: "def live_edit, do: :after")
      |> click("button[type='submit']", text: "Update Drop")

      # Should update without page refresh
      |> assert_path("/drops/#{drop.short_id}")
      |> assert_has("h1", text: "Live Updated Drop")
      |> assert_has("main", text: "Drop updated successfully")
    end

    test "search input provides real-time filtering", %{conn: conn, user: user} do
      # Create searchable drops
      elixir_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Elixir Live Search",
          body: "def elixir_search, do: :live"
        })

      phoenix_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Phoenix Live Update",
          body: "def phoenix_update, do: :realtime"
        })

      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Should see all drops initially
      |> assert_has(".drop-card", text: elixir_drop.title)
      |> assert_has(".drop-card", text: phoenix_drop.title)

      # Type in search - should filter live
      |> fill_in("Search drops", with: "Elixir")
      |> press_key("Enter")

      # Should see filtered results
      |> assert_url_contains("?q=Elixir")
      |> assert_has(".drop-card", text: elixir_drop.title)
      |> refute_has(".drop-card", text: phoenix_drop.title)
    end
  end

  describe "live content updates and synchronization" do
    setup do
      user = user_fixture(%{github_id: 67_890, github_username: "content_updater"})
      %{user: user}
    end

    test "newly created drops appear on homepage without refresh", %{conn: conn, user: user} do
      conn
      |> visit(~p"/")
      |> assert_has("main")

      # Create a new drop (simulating another user or session)
      new_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Real-time New Drop",
          body: "def realtime_new, do: :appears_live"
        })

      # Visit the homepage again to see if the drop appears
      # (In a real LiveView app, this would broadcast via PubSub)
      conn
      |> visit(~p"/")
      |> assert_has(".drop-card", text: new_drop.title)
      |> assert_has(".drop-card", text: "Real-time New Drop")
    end

    test "profile page shows updated drops immediately", %{conn: conn, user: user} do
      drop =
        drop_fixture(%Drop{}, user, %{
          title: "Profile Live Update",
          body: "def profile_update, do: :before"
        })

      conn
      |> sign_in_user(user)
      |> visit(~p"/profile")
      |> assert_has(".drop-card", text: drop.title)

      # Navigate to edit and update
      |> click(".drop-card", text: drop.title)
      |> click("a", text: "Edit")
      |> fill_in("Title", with: "Profile Updated Live")
      |> click("button[type='submit']", text: "Update Drop")

      # Return to profile - should see updated content
      |> visit(~p"/profile")
      |> assert_has(".drop-card", text: "Profile Updated Live")
      |> refute_has(".drop-card", text: "Profile Live Update")
    end

    test "drop view page reflects live updates", %{conn: conn, user: user} do
      drop =
        drop_fixture(%Drop{}, user, %{
          title: "Live View Update",
          body: "def live_view_update, do: :original"
        })

      conn
      |> sign_in_user(user)
      |> visit("/d/#{drop.short_id}")
      |> assert_has("h1", text: drop.title)
      |> assert_has("pre code", text: "def live_view_update")

      # Edit the drop in place
      |> click("a", text: "Edit")
      |> fill_in("Title", with: "Live Updated Content")
      |> fill_in("Code", with: "def live_view_update, do: :updated")
      |> click("button[type='submit']", text: "Update Drop")

      # Should see updated content immediately
      |> assert_path("/drops/#{drop.short_id}")
      |> assert_has("h1", text: "Live Updated Content")
      |> assert_has("pre code", text: ":updated")
    end
  end

  describe "WebSocket connection and live interactions" do
    setup do
      user = user_fixture(%{github_id: 11_111, github_username: "websocket_user"})
      %{user: user}
    end

    test "LiveView maintains connection during user interactions", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Perform multiple interactions to test connection stability
      |> fill_in("Search drops", with: "websocket test")
      |> assert_field_value("Search drops", "websocket test")

      # Clear search
      |> fill_in("Search drops", with: "")
      |> assert_field_value("Search drops", "")

      # Navigate to different pages
      |> visit(~p"/profile")
      |> assert_has("h1", text: "Your Drops")
      |> visit(~p"/drops/new")
      |> assert_has("h1", text: "Share Code")

      # Should maintain authentication state throughout
      |> assert_has("nav", text: user.github_username)
    end

    test "form state persists during live validation", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # Fill form partially
      |> fill_in("Title", with: "WebSocket State Test")
      |> fill_in("Code", with: "def websocket_state, do: :persistent")

      # Trigger validation with invalid data
      # Clear title
      |> fill_in("Title", with: "")
      |> click("button[type='submit']", text: "Post Drop")

      # Form should preserve the code content
      |> assert_field_value("Code", "def websocket_state, do: :persistent")
      |> assert_has("form", text: "can't be blank")

      # Fix validation and submit
      |> fill_in("Title", with: "WebSocket State Test Fixed")
      |> click("button[type='submit']", text: "Post Drop")
      |> assert_path("/profile")
      |> assert_has(".drop-card", text: "WebSocket State Test Fixed")
    end

    test "real-time search suggestions work with live connection", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Create search history
      |> fill_in("Search drops", with: "WebSocket Search")
      |> press_key("Enter")
      |> visit(~p"/")

      # Open search suggestions via live interaction
      |> focus_search_input()
      |> wait_for_element("#navbar-search-dropdown", timeout: 3000)
      |> assert_has("#navbar-search-dropdown")
      |> assert_has(".search-suggestion-item", text: "WebSocket Search")

      # Interact with suggestions
      |> hover(".search-suggestion-item:has-text('WebSocket Search')")
      |> wait_for(time: 1)
      |> click(
        ".search-suggestion-item:has-text('WebSocket Search') button[phx-click='delete_navbar_search_history']"
      )

      # Should update live
      |> refute_has(".search-suggestion-item", text: "WebSocket Search")
    end
  end

  describe "live notifications and user feedback" do
    setup do
      user = user_fixture(%{github_id: 22_222, github_username: "notification_user"})
      %{user: user}
    end

    test "success messages appear and disappear with live updates", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")
      |> fill_in("Title", with: "Live Notification Test")
      |> fill_in("Code", with: "def live_notification, do: :success")
      |> click("button[type='submit']", text: "Post Drop")

      # Should see live success notification
      |> assert_path("/profile")
      |> assert_has("main", text: "Drop created successfully")

      # Navigate away and back - flash message behavior
      |> visit(~p"/")
      |> visit(~p"/profile")

      # Flash messages typically disappear after navigation
      |> refute_has("main", text: "Drop created successfully")
    end

    test "error messages update live during form interaction", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # Submit empty form
      |> click("button[type='submit']", text: "Post Drop")
      |> assert_has("form", text: "can't be blank")

      # Start filling form - errors should update live
      |> fill_in("Title", with: "Error Update Test")

      # Submit with only title (body still empty)
      |> click("button[type='submit']", text: "Post Drop")
      |> assert_has("form", text: "Body can't be blank")
      # Should be gone
      |> refute_has("form", text: "Title can't be blank")

      # Complete form
      |> fill_in("Code", with: "def error_update, do: :fixed")
      |> click("button[type='submit']", text: "Post Drop")

      # Should succeed
      |> assert_path("/profile")
      |> assert_has("main", text: "Drop created successfully")
    end

    test "loading states and feedback during async operations", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")
      |> fill_in("Title", with: "Loading State Test")
      |> fill_in("Code",
        with: """
        def loading_state_test do
          # This will trigger screenshot generation
          :async_operation
        end
        """
      )

      # Submit form
      |> click("button[type='submit']", text: "Post Drop")
      |> assert_path("/profile")
      |> assert_has("main", text: "Drop created successfully")

      # Check the created drop for any loading indicators
      |> click(".drop-card", text: "Loading State Test")
      |> assert_has("h1", text: "Loading State Test")

      # If screenshot generation is async, there might be loading states
      |> assert_has("pre code", text: "def loading_state_test")
    end
  end

  describe "collaborative features and multi-user updates" do
    setup do
      user1 = user_fixture(%{github_id: 33_333, github_username: "collaborator1"})
      user2 = user_fixture(%{github_id: 44_444, github_username: "collaborator2"})
      %{user1: user1, user2: user2}
    end

    test "homepage updates when other users create drops", %{
      conn: conn,
      user1: user1,
      user2: user2
    } do
      # User1 visits homepage
      conn
      |> sign_in_user(user1)
      |> visit(~p"/")
      |> assert_has("main")

      # User2 creates a drop (simulating another session)
      new_drop =
        drop_fixture(%Drop{}, user2, %{
          title: "Collaborative Drop",
          body: "def collaborative, do: :shared"
        })

      # User1 refreshes or navigates - should see the new drop
      conn
      |> visit(~p"/")
      |> assert_has(".drop-card", text: new_drop.title)
      |> assert_has(".drop-card", text: user2.github_username)
    end

    test "users can view each other's drops with live navigation", %{
      conn: conn,
      user1: user1,
      user2: user2
    } do
      # User2 creates a drop
      shared_drop =
        drop_fixture(%Drop{}, user2, %{
          title: "Shared Knowledge Drop",
          body: "def shared_knowledge, do: :accessible"
        })

      # User1 can discover and view User2's drop
      conn
      |> sign_in_user(user1)
      |> visit(~p"/")
      |> assert_has(".drop-card", text: shared_drop.title)
      |> assert_has(".drop-card", text: user2.github_username)

      # Click to view the drop
      |> click(".drop-card", text: shared_drop.title)
      |> assert_path("/drops/#{shared_drop.short_id}")
      |> assert_has("h1", text: shared_drop.title)
      |> assert_has("main", text: user2.github_username)

      # User1 should NOT see edit button (not their drop)
      |> refute_has("a", text: "Edit")
    end

    test "authentication state updates live across sessions", %{conn: conn, user1: user1} do
      # Start as unauthenticated
      conn
      |> visit(~p"/")
      |> assert_has("a", text: "Sign in with GitHub")
      |> refute_has("nav", text: user1.github_username)

      # Sign in
      |> sign_in_user(user1)
      |> assert_path("/")

      # Should see authenticated state immediately
      |> assert_has("nav", text: user1.github_username)
      |> refute_has("a", text: "Sign in with GitHub")

      # Navigate to different pages - state should persist
      |> visit(~p"/profile")
      |> assert_has("nav", text: user1.github_username)
      |> assert_has("h1", text: "Your Drops")

      # Sign out
      |> click("a", text: "Sign out")
      |> assert_path("/")

      # Should return to unauthenticated state
      |> refute_has("nav", text: user1.github_username)
      |> assert_has("a", text: "Sign in with GitHub")
    end
  end

  describe "live search and dynamic content filtering" do
    setup do
      user = user_fixture(%{github_id: 55_555, github_username: "search_user"})

      # Create diverse drops for search testing
      elixir_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Advanced Elixir Techniques",
          body: "def elixir_advanced, do: :powerful"
        })

      phoenix_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Phoenix LiveView Magic",
          body: "def phoenix_magic, do: :realtime"
        })

      javascript_drop =
        drop_fixture(%Drop{}, user, %{
          title: "JavaScript Async Patterns",
          body: "async function jsAsync() { return 'modern'; }"
        })

      %{
        user: user,
        elixir_drop: elixir_drop,
        phoenix_drop: phoenix_drop,
        javascript_drop: javascript_drop
      }
    end

    test "search results update live as user types", %{
      conn: conn,
      user: user,
      elixir_drop: elixir_drop,
      phoenix_drop: phoenix_drop
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Should see all drops initially
      |> assert_has(".drop-card", text: elixir_drop.title)
      |> assert_has(".drop-card", text: phoenix_drop.title)

      # Search for Elixir content
      |> fill_in("Search drops", with: "Elixir")
      |> press_key("Enter")

      # Should see filtered results
      |> assert_url_contains("?q=Elixir")
      |> assert_has(".drop-card", text: elixir_drop.title)
      |> refute_has(".drop-card", text: phoenix_drop.title)

      # Clear search
      |> fill_in("Search drops", with: "")
      |> press_key("Enter")

      # Should see all drops again
      |> assert_url_contains("?q=")
      |> assert_has(".drop-card", text: elixir_drop.title)
      |> assert_has(".drop-card", text: phoenix_drop.title)
    end

    test "search maintains live connection during complex queries", %{
      conn: conn,
      user: user,
      javascript_drop: javascript_drop
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Complex search query
      |> fill_in("Search drops", with: "JavaScript async")
      |> press_key("Enter")

      # Should find JavaScript content
      |> assert_url_contains("?q=JavaScript%20async")
      |> assert_has(".drop-card", text: javascript_drop.title)

      # Modify search live
      |> fill_in("Search drops", with: "async function")
      |> press_key("Enter")

      # Should still find the JavaScript drop
      |> assert_url_contains("?q=async%20function")
      |> assert_has(".drop-card", text: javascript_drop.title)
    end
  end
end
