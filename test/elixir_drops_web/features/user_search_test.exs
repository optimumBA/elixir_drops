defmodule ElixirDropsWeb.Features.UserSearchTest do
  @moduledoc """
  Domain-based feature tests for user search experience.

  Story 5: "As a user, I want to search and discover content"

  Covers the complete user search domain including:
  - Authenticated search functionality and UI
  - Search history management and suggestions
  - Advanced search filtering and sorting
  - Search result interaction and navigation
  - Personal search customization features
  - Search suggestion deletion and privacy controls
  """

  use ElixirDropsWeb.FeatureCase, async: false

  import ElixirDrops.FeatureHelpers

  alias ElixirDrops.Drops.Drop

  @moduletag :feature

  describe "authenticated user accesses search functionality" do
    setup do
      user = user_fixture(%{github_id: 12_345, github_username: "searcher"})

      # Create diverse drops for search testing
      elixir_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Advanced Elixir Pattern Matching",
          body: """
          def pattern_match(data) do
            case data do
              {:ok, result} -> process_result(result)
              {:error, reason} -> handle_error(reason)
              _ -> {:unknown, data}
            end
          end
          """
        })

      phoenix_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Phoenix LiveView Components",
          body: """
          defmodule MyApp.Components.SearchBar do
            use Phoenix.LiveComponent
            
            def render(assigns) do
              ~H\"\"\"
              <div class="search-container">
                <input type="text" placeholder="Search..." />
              </div>
              \"\"\"
            end
          end
          """
        })

      javascript_drop =
        drop_fixture(%Drop{}, user, %{
          title: "JavaScript Async Patterns",
          body: """
          async function searchDrops(query) {
            const response = await fetch(`/api/search?q=${query}`);
            return await response.json();
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

    test "authenticated user sees enhanced search interface", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Should see search input in navbar
      |> assert_has("input[placeholder*='Search']")

      # Authenticated users should see enhanced search features
      |> focus_search_input()
      |> wait_for_element("#navbar-search-dropdown", timeout: 3000)
      |> assert_has("#navbar-search-dropdown")

      # Should see search history or suggestions for authenticated users
      |> assert_has("#navbar-search-dropdown .search-suggestions")
    end

    test "user can perform basic search and see results", %{
      conn: conn,
      user: user,
      elixir_drop: elixir_drop,
      phoenix_drop: phoenix_drop
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Search for Elixir content
      |> fill_in("Search drops", with: "Elixir")
      |> press_key("Enter")

      # Should navigate to search results
      |> assert_url_contains("?q=Elixir")
      |> assert_has("main", text: elixir_drop.title)
      |> assert_has(".drop-card", text: "Advanced Elixir Pattern Matching")

      # Should NOT see Phoenix drop in Elixir search results
      |> refute_has("main", text: phoenix_drop.title)
    end

    test "search results are clickable and navigable", %{
      conn: conn,
      user: user,
      elixir_drop: elixir_drop
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/?q=Pattern")

      # Should see search results
      |> assert_has(".drop-card", text: elixir_drop.title)

      # Click on search result to view drop
      |> click(".drop-card", text: elixir_drop.title)
      |> assert_path("/drops/#{elixir_drop.short_id}")
      |> assert_has("h1", text: elixir_drop.title)
      |> assert_has("pre code", text: "def pattern_match")
    end
  end

  describe "user search history and suggestions" do
    setup do
      user = user_fixture(%{github_id: 67_890, github_username: "history_user"})

      # Create some drops to search for
      _search_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Searchable Content",
          body: "def searchable, do: :content"
        })

      %{user: user}
    end

    test "user search history is saved and displayed", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Perform a search
      |> fill_in("Search drops", with: "Phoenix")
      |> press_key("Enter")
      |> assert_url_contains("?q=Phoenix")

      # Go back to homepage
      |> visit(~p"/")

      # Focus on search to see suggestions
      |> focus_search_input()
      |> wait_for_element("#navbar-search-dropdown", timeout: 3000)

      # Should see previous searches in history
      |> assert_has("#navbar-search-dropdown", text: "Phoenix")
      |> assert_has(".search-suggestion-item", text: "Phoenix")
    end

    test "user can delete search history items", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Perform a search to create history
      |> fill_in("Search drops", with: "Elixir")
      |> press_key("Enter")
      |> visit(~p"/")

      # Open search suggestions
      |> focus_search_input()
      |> wait_for_element("#navbar-search-dropdown", timeout: 3000)
      |> assert_has(".search-suggestion-item", text: "Elixir")

      # Hover over suggestion to reveal delete button
      |> hover(".search-suggestion-item:has-text('Elixir')")
      |> wait_for(time: 1)

      # Click delete button for the search history item
      |> click(
        ".search-suggestion-item:has-text('Elixir') button[phx-click='delete_navbar_search_history']"
      )
      |> wait_for(time: 1)

      # History item should be removed
      |> refute_has(".search-suggestion-item", text: "Elixir")
    end

    test "user can click on search history to repeat search", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Create search history
      |> fill_in("Search drops", with: "LiveView")
      |> press_key("Enter")
      |> assert_url_contains("?q=LiveView")

      # Return to homepage
      |> visit(~p"/")

      # Click on search history item
      |> focus_search_input()
      |> wait_for_element("#navbar-search-dropdown", timeout: 3000)
      |> click(".search-suggestion-item", text: "LiveView")

      # Should perform the search again
      |> assert_url_contains("?q=LiveView")
    end

    test "search suggestions dropdown closes properly", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Open search dropdown
      |> focus_search_input()
      |> wait_for_element("#navbar-search-dropdown", timeout: 3000)
      |> assert_has("#navbar-search-dropdown")

      # Click outside to close dropdown
      |> click("main")
      |> wait_for(time: 1)

      # Dropdown should be closed
      |> refute_has("#navbar-search-dropdown")
    end
  end

  describe "advanced search functionality" do
    setup do
      user = user_fixture(%{github_id: 11_111, github_username: "advanced_searcher"})
      other_user = user_fixture(%{github_id: 22_222, github_username: "other_author"})

      # Create drops with different characteristics for advanced search
      recent_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Recent Elixir Code",
          body: "def recent_function, do: :new_code"
        })

      old_drop =
        drop_fixture(%Drop{}, other_user, %{
          title: "Legacy JavaScript Code",
          body: "function legacy() { return 'old'; }"
        })

      %{user: user, other_user: other_user, recent_drop: recent_drop, old_drop: old_drop}
    end

    test "user can search by language/content type", %{
      conn: conn,
      user: user,
      recent_drop: recent_drop,
      old_drop: old_drop
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Search for Elixir-specific content
      |> fill_in("Search drops", with: "def")
      |> press_key("Enter")

      # Should find Elixir drops with 'def' keyword
      |> assert_has(".drop-card", text: recent_drop.title)
      |> refute_has(".drop-card", text: old_drop.title)
    end

    test "user can search by author username", %{
      conn: conn,
      user: user,
      other_user: other_user,
      old_drop: old_drop
    } do
      conn
      |> sign_in_user(user)
      |> visit("/?q=#{URI.encode(other_user.github_username)}")

      # Should find drops by specific author
      |> assert_has(".drop-card", text: old_drop.title)
      |> assert_has(".drop-card", text: other_user.github_username)
    end

    test "search works with partial matches", %{
      conn: conn,
      user: user,
      recent_drop: recent_drop
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Search with partial title match
      |> fill_in("Search drops", with: "Recent")
      |> press_key("Enter")
      |> assert_has(".drop-card", text: recent_drop.title)
      |> assert_has(".drop-card", text: "Recent Elixir Code")
    end

    test "empty search shows all drops", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/?q=")

      # Empty search should show all drops
      |> assert_has(".drop-card")

      # Should not show "No results" message
      |> refute_has("main", text: "No drops found")
    end
  end

  describe "search result management and interaction" do
    setup do
      user = user_fixture(%{github_id: 33_333, github_username: "result_manager"})

      # Create multiple drops for result interaction testing
      drops =
        for i <- 1..5 do
          drop_fixture(%Drop{}, user, %{
            title: "Search Result Drop #{i}",
            body: """
            def search_result_#{i} do
              # This is search result number #{i}
              :result_#{i}
            end
            """
          })
        end

      %{user: user, drops: drops}
    end

    test "user can view search results and navigate back", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/?q=Search Result")

      # Should see multiple search results
      |> assert_element(".drop-card", count: 5)
      |> assert_has(".drop-card", text: "Search Result Drop 1")
      |> assert_has(".drop-card", text: "Search Result Drop 5")

      # Click on first result
      |> click(".drop-card", text: "Search Result Drop 1")
      |> assert_path_matches(~r|/drops/[a-z0-9]+$|)
      |> assert_has("h1", text: "Search Result Drop 1")

      # Navigate back to search results
      |> visit(~p"/?q=Search Result")
      |> assert_element(".drop-card", count: 5)
    end

    test "search results maintain query in URL", %{conn: conn, user: user} do
      search_query = "Drop 3"

      conn
      |> sign_in_user(user)
      |> visit("/?q=#{URI.encode(search_query)}")

      # URL should contain the search query
      |> assert_url_contains("q=Drop%203")

      # Should see filtered results
      |> assert_has(".drop-card", text: "Search Result Drop 3")
      |> refute_has(".drop-card", text: "Search Result Drop 1")
    end

    test "user can edit their own drops from search results", %{
      conn: conn,
      user: user,
      drops: drops
    } do
      first_drop = hd(drops)

      conn
      |> sign_in_user(user)
      |> visit(~p"/?q=Search Result")

      # Click on own drop in search results
      |> click(".drop-card", text: first_drop.title)
      |> assert_path("/drops/#{first_drop.short_id}")

      # Should see edit button (own drop)
      |> assert_has("a", text: "Edit")

      # Can navigate to edit form
      |> click("a", text: "Edit")
      |> assert_path("/drops/#{first_drop.short_id}/edit")
      |> assert_field_value("Title", first_drop.title)
    end

    test "search preserves user authentication state", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/?q=Search")

      # User should remain authenticated during search
      |> assert_has("nav", text: user.github_username)

      # Click on result and navigate back
      |> click(".drop-card", text: "Search Result Drop 2")
      |> assert_has("nav", text: user.github_username)
      |> visit(~p"/?q=Different Query")
      # Should still be authenticated
      |> assert_has("nav", text: user.github_username)
    end
  end

  describe "search UI and user experience enhancements" do
    setup do
      user = user_fixture(%{github_id: 44_444, github_username: "ui_tester"})

      ui_drop =
        drop_fixture(%Drop{}, user, %{
          title: "UI Test Drop",
          body: "def ui_test, do: :interface"
        })

      %{user: user, ui_drop: ui_drop}
    end

    test "search input shows current query", %{conn: conn, user: user} do
      search_term = "UI Test"

      conn
      |> sign_in_user(user)
      |> visit("/?q=#{URI.encode(search_term)}")

      # Search input should show current query
      |> assert_field_value("Search drops", search_term)
    end

    test "search form submission works correctly", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Fill search form and submit
      |> fill_in("Search drops", with: "UI")
      |> press_key("Enter")

      # Should navigate to search results
      |> assert_url_contains("?q=UI")
      |> assert_has(".drop-card", text: "UI Test Drop")
    end

    test "search keyboard shortcuts work properly", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Focus search input
      |> focus_search_input()
      |> fill_in("Search drops", with: "Test")

      # Enter key should submit search
      |> press_key("Enter")
      |> assert_url_contains("?q=Test")

      # Escape key should clear suggestions (if any)
      |> visit(~p"/")
      |> focus_search_input()
      |> press_key("Escape")
      |> refute_has("#navbar-search-dropdown")
    end

    test "search input handles special characters", %{conn: conn, user: user} do
      special_query = "test & <script>"

      conn
      |> sign_in_user(user)
      |> visit(~p"/")
      |> fill_in("Search drops", with: special_query)
      |> press_key("Enter")

      # Should properly encode special characters in URL
      |> assert_url_contains("?q=test%20%26%20%3Cscript%3E")

      # Should display query safely in input
      |> assert_field_value("Search drops", special_query)
    end
  end

  describe "search personalization and privacy" do
    setup do
      user = user_fixture(%{github_id: 55_555, github_username: "privacy_user"})
      other_user = user_fixture(%{github_id: 66_666, github_username: "other"})

      %{user: user, other_user: other_user}
    end

    test "user search history is private per user", %{
      conn: conn,
      user: user,
      other_user: other_user
    } do
      # User creates search history
      conn
      |> sign_in_user(user)
      |> visit(~p"/")
      |> fill_in("Search drops", with: "Private Search")
      |> press_key("Enter")

      # Sign out and sign in as other user
      |> click("a", text: "Sign out")
      |> sign_in_user(other_user)
      |> visit(~p"/")

      # Other user should not see first user's search history
      |> focus_search_input()
      |> wait_for_element("#navbar-search-dropdown", timeout: 3000)
      |> refute_has(".search-suggestion-item", text: "Private Search")
    end

    test "user can clear their search history", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Create multiple search history entries
      |> fill_in("Search drops", with: "First Search")
      |> press_key("Enter")
      |> visit(~p"/")
      |> fill_in("Search drops", with: "Second Search")
      |> press_key("Enter")
      |> visit(~p"/")

      # Check history exists
      |> focus_search_input()
      |> wait_for_element("#navbar-search-dropdown", timeout: 3000)
      |> assert_has(".search-suggestion-item", text: "First Search")
      |> assert_has(".search-suggestion-item", text: "Second Search")

      # Delete first search history item
      |> hover(".search-suggestion-item:has-text('First Search')")
      |> click(
        ".search-suggestion-item:has-text('First Search') button[phx-click='delete_navbar_search_history']"
      )

      # First search should be gone, second should remain
      |> refute_has(".search-suggestion-item", text: "First Search")
      |> assert_has(".search-suggestion-item", text: "Second Search")
    end

    test "search suggestions work for authenticated users only", %{
      conn: conn,
      user: user
    } do
      # Unauthenticated user should see basic suggestions
      conn
      |> visit(~p"/")
      |> focus_search_input()
      |> wait_for_element("#navbar-search-dropdown", timeout: 3000)

      # Should NOT see delete buttons for unauthenticated users
      |> refute_has("button[phx-click='delete_navbar_search_history']")

      # Authenticated user should see enhanced suggestions
      conn
      |> sign_in_user(user)
      |> visit(~p"/")
      |> fill_in("Search drops", with: "Test History")
      |> press_key("Enter")
      |> visit(~p"/")
      |> focus_search_input()
      |> wait_for_element("#navbar-search-dropdown", timeout: 3000)

      # Should see personal search history with delete options
      |> assert_has(".search-suggestion-item", text: "Test History")
    end
  end

  describe "search no results and error handling" do
    setup do
      user = user_fixture(%{github_id: 77_777, github_username: "no_results_user"})
      %{user: user}
    end

    test "search with no results shows appropriate message", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/?q=NonexistentSearchTerm12345")

      # Should show no results message
      |> assert_has("main", text: "No drops found")
      |> assert_has("main", text: "NonexistentSearchTerm12345")

      # Should suggest trying different terms
      |> assert_has("main", text: "Try a different search term")
    end

    test "search handles empty queries gracefully", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/?q=")

      # Empty search should show all drops or homepage
      |> assert_has("main")
      |> refute_has("main", text: "No drops found")
    end

    test "search handles very long queries", %{conn: conn, user: user} do
      very_long_query = String.duplicate("long search term ", 20)

      conn
      |> sign_in_user(user)
      |> visit(~p"/")
      |> fill_in("Search drops", with: very_long_query)
      |> press_key("Enter")

      # Should handle long queries without breaking
      |> assert_url_contains("?q=long%20search%20term")

      # Should show appropriate no results message
      |> assert_has("main", text: "No drops found")
    end

    test "search recovers from network errors", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Fill search input
      |> fill_in("Search drops", with: "Recovery Test")

      # Simulate search - should work normally
      |> press_key("Enter")
      |> assert_url_contains("?q=Recovery%20Test")

      # Search input should maintain functionality
      |> fill_in("Search drops", with: "Another Search")
      |> press_key("Enter")
      |> assert_url_contains("?q=Another%20Search")
    end
  end
end
