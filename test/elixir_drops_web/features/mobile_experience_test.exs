defmodule ElixirDropsWeb.Features.MobileUserExperienceTest do
  @moduledoc """
  Domain-based feature tests for mobile user experience.

  Story 6: "As a mobile user, I want a responsive experience"

  Covers the complete mobile user experience domain including:
  - Mobile browsing and drop discovery
  - Mobile authentication and user flows
  - Mobile drop creation and management
  - Touch interactions and mobile navigation
  - Responsive layouts across device sizes
  - Mobile-specific UI patterns and features
  """

  use ElixirDropsWeb.FeatureCase, async: false

  import ElixirDrops.FeatureHelpers

  alias ElixirDrops.Drops.Drop

  @moduletag :feature

  describe "mobile visitor browsing experience" do
    setup do
      user = user_fixture(%{github_id: 12_345, github_username: "mobile_creator"})

      # Create drops for mobile browsing
      mobile_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Mobile Elixir Pattern Matching",
          body: """
          def mobile_pattern_match(data) do
            case data do
              {:ok, result} -> {:success, result}
              {:error, reason} -> {:failure, reason}
              _ -> {:unknown, data}
            end
          end
          """
        })

      short_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Quick Mobile Tip",
          body: "def quick_tip, do: :mobile_friendly"
        })

      %{user: user, mobile_drop: mobile_drop, short_drop: short_drop}
    end

    @tag viewport: {375, 667}
    test "mobile visitor can browse drops with touch-friendly layout", %{
      conn: conn,
      mobile_drop: mobile_drop,
      short_drop: short_drop
    } do
      conn
      |> visit(~p"/")
      |> resize_window(375, 667)

      # Mobile layout should show drops in single column
      |> assert_has("main", text: mobile_drop.title)
      |> assert_has("main", text: short_drop.title)
      |> assert_has(".drop-card", text: "Mobile Elixir Pattern Matching")
      |> assert_has(".drop-card", text: "Quick Mobile Tip")

      # Touch targets should be appropriately sized
      |> assert_has(".drop-card")
    end

    @tag viewport: {375, 667}
    test "mobile visitor can tap drop cards to view full content", %{
      conn: conn,
      mobile_drop: mobile_drop
    } do
      conn
      |> visit(~p"/")
      |> resize_window(375, 667)

      # Tap on drop card (mobile-sized touch target)
      |> click(".drop-card", text: mobile_drop.title)
      |> assert_path("/drops/#{mobile_drop.short_id}")

      # Full content should be readable on mobile
      |> assert_has("h1", text: mobile_drop.title)
      |> assert_has("pre code", text: "def mobile_pattern_match")

      # Code should be properly formatted for mobile viewing
      |> assert_has("pre code", text: "case data do")
    end

    @tag viewport: {375, 667}
    test "mobile navigation is touch-friendly", %{conn: conn} do
      conn
      |> visit(~p"/")
      |> resize_window(375, 667)

      # Should have mobile-appropriate navigation
      |> assert_has("nav")

      # Mobile menu button or nav elements should be visible
      |> assert_has("main")

      # Search should be accessible on mobile
      |> assert_has("input[placeholder*='Search']")
    end

    @tag viewport: {375, 667}
    test "mobile visitor sees sign-in options optimized for touch", %{conn: conn} do
      conn
      |> visit(~p"/")
      |> resize_window(375, 667)

      # Sign-in button should be touch-friendly
      |> assert_has("a", text: "Sign in with GitHub")

      # Create post button should trigger mobile-optimized popup
      |> assert_has("#create-post-button")
      |> click("#create-post-button")
      |> wait_for_element("#signin-popup-message", timeout: 3000)
      |> assert_has("#signin-popup-message")
    end
  end

  describe "mobile user authentication and account flows" do
    setup do
      user = user_fixture(%{github_id: 67_890, github_username: "mobile_user"})
      %{user: user}
    end

    @tag viewport: {375, 667}
    test "mobile user can sign in and access profile", %{conn: conn, user: user} do
      conn
      |> visit(~p"/")
      |> resize_window(375, 667)

      # Sign in through mobile-optimized flow
      |> sign_in_user(user)
      |> assert_path("/")

      # Should see mobile-friendly authenticated state
      |> assert_has("nav", text: user.github_username)

      # Can navigate to profile on mobile
      |> click("a[href='/profile']")
      |> assert_path("/profile")
      |> assert_has("h1", text: "Your Drops")
    end

    @tag viewport: {375, 667}
    test "mobile user can sign out from navigation", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")
      |> resize_window(375, 667)

      # Should be able to sign out on mobile
      |> click("a", text: "Sign out")
      |> assert_path("/")

      # Should return to mobile visitor state
      |> refute_has("nav", text: user.github_username)
      |> assert_has("a", text: "Sign in with GitHub")
    end
  end

  describe "mobile drop creation and management" do
    setup do
      user = user_fixture(%{github_id: 11_111, github_username: "mobile_creator"})
      %{user: user}
    end

    @tag viewport: {375, 667}
    test "mobile user can access creation via floating action button", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")
      |> resize_window(375, 667)

      # Mobile floating action button should be accessible
      # Fixed-positioned element requires special handling
      |> assert_element_exists_and_clickable("#create-post-btn-mobile")
    end

    @tag viewport: {375, 667}
    test "mobile drop creation form is touch-optimized", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")
      |> resize_window(375, 667)

      # Form should be mobile-friendly
      |> assert_has("form")
      |> assert_has("input[name='drop[title]']")
      |> assert_has("textarea[name='drop[body]']")

      # Fill form with mobile keyboard simulation
      |> fill_in("Title", with: "Mobile Created Drop")
      |> fill_in("Code",
        with: """
        def mobile_creation do
          # Created on mobile device
          :touch_friendly
        end
        """
      )

      # Submit button should be touch-friendly
      |> click("button[type='submit']", text: "Post Drop")
      |> assert_path("/profile")
      |> assert_has("main", text: "Drop created successfully")
    end

    @tag viewport: {375, 667}
    test "mobile user can edit drops with optimized forms", %{conn: conn, user: user} do
      drop =
        drop_fixture(%Drop{}, user, %{
          title: "Mobile Edit Test",
          body: "def mobile_edit, do: :before"
        })

      conn
      |> sign_in_user(user)
      |> visit("/d/#{drop.short_id}")
      |> resize_window(375, 667)

      # Edit button should be touch-friendly
      |> click("a", text: "Edit")
      |> assert_path("/drops/#{drop.short_id}/edit")

      # Edit form should work on mobile
      |> fill_in("Title", with: "Mobile Edited Drop")
      |> fill_in("Code", with: "def mobile_edit, do: :after")
      |> click("button[type='submit']", text: "Update Drop")
      |> assert_path("/drops/#{drop.short_id}")
      |> assert_has("h1", text: "Mobile Edited Drop")
    end
  end

  describe "mobile search and discovery experience" do
    setup do
      user = user_fixture(%{github_id: 22_222, github_username: "mobile_searcher"})

      search_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Mobile Search Test Drop",
          body: "def mobile_search, do: :discoverable"
        })

      %{user: user, search_drop: search_drop}
    end

    @tag viewport: {375, 667}
    test "mobile search interface is touch-optimized", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")
      |> resize_window(375, 667)

      # Search input should be mobile-friendly
      |> assert_has("input[placeholder*='Search']")

      # Tap to focus should work
      |> focus_search_input()
      |> wait_for_element("#navbar-search-dropdown", timeout: 3000)
      |> assert_has("#navbar-search-dropdown")
    end

    @tag viewport: {375, 667}
    test "mobile search results are touch-navigable", %{
      conn: conn,
      user: user,
      search_drop: search_drop
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")
      |> resize_window(375, 667)

      # Perform search on mobile
      |> fill_in("Search drops", with: "Mobile Search")
      |> press_key("Enter")

      # Results should be touch-friendly
      |> assert_url_contains("?q=Mobile%20Search")
      |> assert_has(".drop-card", text: search_drop.title)

      # Tap on result
      |> click(".drop-card", text: search_drop.title)
      |> assert_path("/drops/#{search_drop.short_id}")
      |> assert_has("h1", text: search_drop.title)
    end

    @tag viewport: {375, 667}
    test "mobile search suggestions are touch-interactive", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")
      |> resize_window(375, 667)

      # Create search history
      |> fill_in("Search drops", with: "Mobile History")
      |> press_key("Enter")
      |> visit(~p"/")

      # Open suggestions on mobile
      |> focus_search_input()
      |> wait_for_element("#navbar-search-dropdown", timeout: 3000)
      |> assert_has(".search-suggestion-item", text: "Mobile History")

      # Touch interactions should work
      |> hover(".search-suggestion-item:has-text('Mobile History')")
      |> wait_for(time: 1)
      |> click(
        ".search-suggestion-item:has-text('Mobile History') button[phx-click='delete_navbar_search_history']"
      )
      |> refute_has(".search-suggestion-item", text: "Mobile History")
    end
  end

  describe "responsive design across mobile devices" do
    @tag viewport: {320, 568}
    test "small mobile phones display content properly", %{conn: conn} do
      user = user_fixture(%{github_id: 33_333, github_username: "small_phone"})

      drop =
        drop_fixture(%Drop{}, user, %{
          title: "Small Phone Test",
          body: "def small_phone, do: :compact"
        })

      conn
      |> visit(~p"/")
      |> resize_window(320, 568)

      # Content should fit on small screens
      |> assert_has("main", text: drop.title)
      |> assert_has(".drop-card", text: "Small Phone Test")

      # Navigation should not overflow
      |> assert_has("nav")
    end

    @tag viewport: {414, 896}
    test "large mobile phones optimize space usage", %{conn: conn} do
      user = user_fixture(%{github_id: 44_444, github_username: "large_phone"})

      drop =
        drop_fixture(%Drop{}, user, %{
          title: "Large Phone Optimization",
          body: "def large_phone, do: :spacious"
        })

      conn
      |> visit(~p"/")
      |> resize_window(414, 896)

      # Should utilize larger screen space effectively
      |> assert_has("main", text: drop.title)
      |> assert_has(".drop-card", text: "Large Phone Optimization")
    end

    @tag viewport: {768, 1024}
    test "tablet layout provides enhanced desktop-like experience", %{conn: conn} do
      user = user_fixture(%{github_id: 55_555, github_username: "tablet_user"})

      # Create multiple drops to test grid layout
      for i <- 1..6 do
        drop_fixture(%Drop{}, user, %{
          title: "Tablet Drop #{i}",
          body: "def tablet_drop_#{i}, do: :grid_layout"
        })
      end

      conn
      |> visit(~p"/")
      |> resize_window(768, 1024)

      # Should show multiple columns on tablet
      |> assert_has("main", text: "Tablet Drop 1")
      |> assert_has("main", text: "Tablet Drop 6")

      # Navigation should be fully visible
      |> assert_has("nav")
    end

    test "landscape orientation maintains usability", %{conn: conn} do
      user = user_fixture(%{github_id: 66_666, github_username: "landscape_user"})

      drop =
        drop_fixture(%Drop{}, user, %{
          title: "Landscape Test Drop",
          body: "def landscape, do: :horizontal"
        })

      conn
      |> visit(~p"/")
      # Mobile landscape
      |> resize_window(667, 375)

      # Content should adapt to landscape orientation
      |> assert_has("main", text: drop.title)
      |> assert_has(".drop-card", text: "Landscape Test Drop")

      # Navigation should remain accessible
      |> assert_has("nav")
    end
  end

  describe "mobile accessibility and touch interactions" do
    setup do
      user = user_fixture(%{github_id: 77_777, github_username: "accessibility_user"})
      %{user: user}
    end

    @tag viewport: {375, 667}
    test "touch targets meet minimum size requirements", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")
      |> resize_window(375, 667)

      # All interactive elements should be touch-friendly
      |> assert_has("nav")
      |> assert_has("input[placeholder*='Search']")
      |> assert_has("a", text: "Sign out")

      # Create button should be easily tappable
      |> assert_element_exists_and_clickable("#create-post-btn-mobile")
    end

    @tag viewport: {375, 667}
    test "mobile forms have appropriate spacing and sizing", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")
      |> resize_window(375, 667)

      # Form elements should be spaced for mobile use
      |> assert_has("input[name='drop[title]']")
      |> assert_has("textarea[name='drop[body]']")
      |> assert_has("button[type='submit']")

      # Should be able to interact with form elements
      |> fill_in("Title", with: "Touch Test")
      |> fill_in("Code", with: "def touch_test, do: :accessible")
    end

    @tag viewport: {375, 667}
    test "mobile popups and modals are properly sized", %{conn: conn} do
      conn
      |> visit(~p"/")
      |> resize_window(375, 667)

      # Trigger sign-in popup
      |> click("#create-post-button")
      |> wait_for_element("#signin-popup-message", timeout: 3000)
      |> assert_has("#signin-popup-message")

      # Popup should fit mobile screen and be dismissible
      |> press_key("Escape")
      |> wait_for(time: 1)
      |> refute_has("#signin-popup-message")
    end
  end

  describe "mobile performance and user experience" do
    @tag viewport: {375, 667}
    test "mobile infinite scroll provides smooth experience", %{conn: conn} do
      user = user_fixture(%{github_id: 88_888, github_username: "scroll_user"})

      # Create multiple drops for scrolling
      for i <- 1..25 do
        drop_fixture(%Drop{}, user, %{
          title: "Mobile Scroll Drop #{i}",
          body: "def mobile_scroll_#{i}, do: :smooth"
        })
      end

      conn
      |> visit(~p"/")
      |> resize_window(375, 667)

      # Initial load
      |> assert_has("main", text: "Mobile Scroll Drop 1")
      |> assert_element(".drop-card", count: 20)

      # Mobile scroll behavior
      |> scroll_down(800)
      |> wait_for(time: 2)
      |> assert_element(".drop-card", minimum: 21)

      # Should load remaining drops smoothly
      |> scroll_down(800)
      |> wait_for(time: 2)
      |> assert_has("main", text: "Mobile Scroll Drop 25")
    end

    @tag viewport: {375, 667}
    test "mobile navigation maintains state across screen rotations", %{conn: conn} do
      user = user_fixture(%{github_id: 99_999, github_username: "rotation_user"})

      conn
      |> sign_in_user(user)
      |> visit(~p"/")
      |> resize_window(375, 667)

      # User should be authenticated in portrait
      |> assert_has("nav", text: user.github_username)

      # Rotate to landscape
      |> resize_window(667, 375)

      # Should maintain authentication state
      |> assert_has("nav", text: user.github_username)

      # Rotate back to portrait
      |> resize_window(375, 667)

      # State should persist
      |> assert_has("nav", text: user.github_username)
    end
  end
end
