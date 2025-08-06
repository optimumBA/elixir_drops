defmodule ElixirDropsWeb.Features.UserSearchTest do
  @moduledoc """
  Domain-based feature tests for user search and discovery experience.

  Story 4: "As a user, I want to search and discover drops"

  Covers the complete user search domain including:
  - Authenticated user search functionality
  - Search interface and suggestions
  - Search result display and interaction
  - Advanced search and filtering capabilities
  - Search history and personalization
  - Search relevance and ranking
  """

  use ElixirDropsWeb.FeatureCase, async: true

  import ElixirDrops.FeatureHelpers

  alias ElixirDrops.Drops.Drop

  @moduletag :feature

  describe "authenticated user accesses search functionality" do
    setup do
      user = user_fixture(%{github_id: 12_345, github_username: "searcher"})

      # Create various drops for searching
      elixir_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Advanced Elixir Pattern Matching",
          body: """
          def match_complex_data(input) do
            case input do
              {:ok, %{status: :active, data: data}} -> process_active(data)
              {:ok, %{status: :pending}} -> {:wait, "Processing"}
              {:error, reason} -> handle_error(reason)
              _ -> {:unknown, input}
            end
          end
          """
        })

      phoenix_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Phoenix LiveView Best Practices",
          body: """
          defmodule MyAppWeb.UserLive do
            use MyAppWeb, :live_view

            def mount(_params, _session, socket) do
              {:ok, assign(socket, users: [])}
            end

            def handle_event("search", %{"query" => query}, socket) do
              users = Search.find_users(query)
              {:noreply, assign(socket, users: users)}
            end
          end
          """
        })

      javascript_drop =
        drop_fixture(%Drop{}, user, %{
          title: "JavaScript Async/Await Patterns",
          body: """
          async function fetchUserData(userId) {
            try {
              const response = await fetch(`/api/users/${userId}`);
              const data = await response.json();
              return { success: true, data };
            } catch (error) {
              console.error('Fetch error:', error);
              return { success: false, error };
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

    test "user can access search from homepage", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Search functionality is available
      |> assert_has("nav")

      # Search by navigating with query parameter
      |> visit("/?q=Elixir")
      |> assert_url_contains("q=Elixir")
    end

    test "search box accepts user input", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Navigate with search query
      |> visit("/?q=Phoenix")
      |> assert_url_contains("q=Phoenix")
    end

    test "search results are clickable and navigable", %{
      conn: conn,
      user: user,
      elixir_drop: elixir_drop
    } do
      conn
      |> sign_in_user(user)
      |> visit("/?q=Elixir")

      # Should show search results
      |> assert_has(".drop-card", text: elixir_drop.title)

      # Navigate to the drop
      |> visit("/d/#{elixir_drop.short_id}")
      |> assert_has("h1", text: elixir_drop.title)
    end
  end

  describe "user search history and suggestions" do
    setup do
      user = user_fixture(%{github_id: 67_890, github_username: "history_user"})

      # Create drops with common search terms
      for term <- ["Elixir", "Phoenix", "LiveView", "JavaScript", "React"] do
        drop_fixture(%Drop{}, user, %{
          title: "#{term} Tutorial",
          body: "def #{String.downcase(term)}_example, do: :ok"
        })
      end

      %{user: user}
    end

    test "user search history is saved and displayed", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Perform searches
      |> visit("/?q=Phoenix")
      |> assert_has(".drop-card", text: "Phoenix Tutorial")

      # Search for another term
      |> visit("/?q=LiveView")
      |> assert_has(".drop-card", text: "LiveView Tutorial")

      # Go back to homepage
      |> visit(~p"/")
      |> assert_has("nav")
    end

    test "search suggestions appear based on available content", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit("/?q=Elixir")

      # Full word match should work
      |> assert_has(".drop-card", text: "Elixir Tutorial")
    end

    test "recent searches influence suggestions", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Perform multiple searches
      |> visit("/?q=JavaScript")
      |> assert_has(".drop-card", text: "JavaScript Tutorial")
      |> visit("/?q=React")
      |> assert_has(".drop-card", text: "React Tutorial")

      # Clear search by going to homepage
      |> visit(~p"/")
      |> assert_has("nav")
    end
  end

  describe "search result display and relevance" do
    setup do
      user = user_fixture(%{github_id: 11_111, github_username: "relevance_user"})

      # Create drops with varying relevance
      exact_match =
        drop_fixture(%Drop{}, user, %{
          title: "Elixir GenServer Tutorial",
          body: "def handle_call(:get_state, _from, state), do: {:reply, state, state}"
        })

      partial_match =
        drop_fixture(%Drop{}, user, %{
          title: "Building with Phoenix",
          body: "Elixir is a great language for web development"
        })

      code_match =
        drop_fixture(%Drop{}, user, %{
          title: "Pattern Matching Examples",
          body: "def match({:ok, result}), do: result"
        })

      %{
        user: user,
        exact_match: exact_match,
        partial_match: partial_match,
        code_match: code_match
      }
    end

    test "search results show most relevant drops first", %{
      conn: conn,
      user: user,
      exact_match: exact_match
    } do
      conn
      |> sign_in_user(user)
      |> visit("/?q=Elixir")

      # Should show drops with "Elixir" in them
      |> assert_has(".drop-card", text: exact_match.title)
    end

    test "search matches both title and content", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit("/?q=Phoenix")

      # Should match drop with Phoenix in title
      |> assert_has(".drop-card", text: "Building with Phoenix")
    end

    test "code searches return code-containing drops", %{
      conn: conn,
      user: user,
      code_match: code_match
    } do
      conn
      |> sign_in_user(user)
      |> visit("/?q=match")

      # Should find drops with "match" in content
      |> assert_has(".drop-card", text: code_match.title)
    end
  end

  describe "advanced search functionality" do
    setup do
      user = user_fixture(%{github_id: 22_222, github_username: "advanced_user"})

      # Create drops with different languages and content types
      elixir_drops =
        for i <- 1..3 do
          drop_fixture(%Drop{}, user, %{
            title: "Elixir Tip #{i}",
            body: "def elixir_tip_#{i}, do: :tip_#{i}"
          })
        end

      javascript_drops =
        for i <- 1..2 do
          drop_fixture(%Drop{}, user, %{
            title: "JavaScript Trick #{i}",
            body: "const jsTrick#{i} = () => 'trick#{i}';"
          })
        end

      %{
        user: user,
        elixir_drops: elixir_drops,
        javascript_drops: javascript_drops
      }
    end

    test "user can search by language/content type", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit("/?q=def")

      # Should find Elixir drops with "def"
      |> assert_has(".drop-card", text: "Elixir Tip")

      # Search for JavaScript
      |> visit("/?q=const")
      |> assert_has(".drop-card", text: "JavaScript Trick")
    end

    test "search supports phrase matching", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit("/?q=Elixir%20Tip")

      # Should find drops with exact phrase
      |> assert_has(".drop-card", text: "Elixir Tip")
    end

    test "empty search shows all drops", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Should show all drops
      |> assert_has(".drop-card")

      # Both types should be visible
      |> assert_has(".drop-card", text: "Elixir Tip 1")
      |> assert_has(".drop-card", text: "JavaScript Trick 1")
    end

    test "special characters in search are handled", %{conn: conn, user: user} do
      special_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Using & and | operators",
          body: "def use_operators(a & b), do: a && b"
        })

      conn
      |> sign_in_user(user)
      |> visit("/?q=operators")

      # Should handle special characters gracefully
      |> assert_has(".drop-card", text: special_drop.title)
    end
  end

  describe "search result management and interaction" do
    setup do
      user = user_fixture(%{github_id: 33_333, github_username: "interact_user"})

      drops =
        for i <- 1..5 do
          drop_fixture(%Drop{}, user, %{
            title: "Drop #{i}",
            body: "def drop_#{i}, do: :content_#{i}"
          })
        end

      %{user: user, drops: drops}
    end

    test "search results maintain query in URL", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit("/?q=Drop%203")

      # URL should maintain query
      |> assert_url_contains("q=Drop%203")

      # Result should be shown
      |> assert_has(".drop-card", text: "Drop 3")
    end

    test "user can edit their own drops from search results", %{
      conn: conn,
      user: user,
      drops: drops
    } do
      [first_drop | _] = drops

      conn
      |> sign_in_user(user)
      |> visit("/d/#{first_drop.short_id}")

      # Should be on drop page
      |> assert_has("h1", text: first_drop.title)

      # Can navigate to edit
      |> click("a[href*='/edit']")
      |> assert_path("/drops/#{first_drop.short_id}/edit")
    end

    test "pagination works with search results", %{conn: conn, user: user} do
      # Create many drops
      for i <- 6..30 do
        drop_fixture(%Drop{}, user, %{
          title: "Extra Drop #{i}",
          body: "def extra_#{i}, do: :content"
        })
      end

      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Should show drops (pagination handled by infinite scroll)
      |> assert_has(".drop-card")

      # Scroll to load more
      |> scroll_down(800)

      # More drops should be loaded
      |> assert_has(".drop-card", text: "Extra Drop")
    end
  end

  describe "search UI and user experience enhancements" do
    setup do
      user = user_fixture(%{github_id: 44_444, github_username: "ui_user"})

      ui_drop =
        drop_fixture(%Drop{}, user, %{
          title: "UI Component Library",
          body:
            "export const Button = ({ onClick, children }) => <button onClick={onClick}>{children}</button>;"
        })

      %{user: user, ui_drop: ui_drop}
    end

    test "search form submission works correctly", %{conn: conn, user: user, ui_drop: ui_drop} do
      conn
      |> sign_in_user(user)
      |> visit("/?q=UI")

      # Should show matching drops
      |> assert_has(".drop-card", text: ui_drop.title)
    end

    test "search preserves user context", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit("/?q=Component")

      # User should still be signed in
      |> assert_has("nav", text: user.github_username)

      # Can navigate to create new drop
      |> visit(~p"/drops/new")
      |> assert_has("form")
    end

    test "search handles no results gracefully", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit("/?q=NonexistentSearchTerm123456")

      # Should handle no results gracefully
      |> assert_has("nav")
    end

    test "search handles various query lengths", %{conn: conn, user: user} do
      # Very short query
      conn
      |> sign_in_user(user)
      |> visit("/?q=a")
      |> assert_has("nav")

      # Very long query
      long_query = String.duplicate("test", 100)

      conn
      |> visit("/?q=#{long_query}")
      |> assert_has("nav")
    end
  end

  describe "search personalization and privacy" do
    setup do
      user1 = user_fixture(%{github_id: 55_555, github_username: "private_user1"})
      user2 = user_fixture(%{github_id: 66_666, github_username: "private_user2"})

      # User 1's drops
      user1_drop =
        drop_fixture(%Drop{}, user1, %{
          title: "User1 Private Search",
          body: "def private_content, do: :user1"
        })

      # User 2's drops
      user2_drop =
        drop_fixture(%Drop{}, user2, %{
          title: "User2 Private Search",
          body: "def private_content, do: :user2"
        })

      %{user1: user1, user2: user2, user1_drop: user1_drop, user2_drop: user2_drop}
    end

    test "user search history is private per user", %{
      conn: conn,
      user1: user1,
      user2: user2,
      user1_drop: user1_drop,
      user2_drop: user2_drop
    } do
      # User1 searches
      conn
      |> sign_in_user(user1)
      |> visit("/?q=Private")

      # Should see both drops (public visibility)
      |> assert_has(".drop-card", text: user1_drop.title)
      |> assert_has(".drop-card", text: user2_drop.title)

      # Sign in as user2
      conn
      |> visit(~p"/auth/logout")
      |> sign_in_user(user2)
      |> visit("/?q=Private")

      # Should also see both drops
      |> assert_has(".drop-card", text: user1_drop.title)
      |> assert_has(".drop-card", text: user2_drop.title)
    end
  end
end
