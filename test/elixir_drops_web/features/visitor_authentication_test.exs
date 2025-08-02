defmodule ElixirDropsWeb.Features.VisitorAuthenticationTest do
  @moduledoc """
  Domain-based feature tests for visitor authentication experience.

  Story 2: "As a visitor, I want to sign in"

  Covers the complete visitor authentication domain including:
  - Authentication flow and sign-in process
  - Protected route access control
  - Sign-in popup interactions and JavaScript behavior
  - Session persistence and user state management
  - Authorization checks and redirect flows
  - Post-authentication user experience
  """

  use ElixirDropsWeb.FeatureCase, async: false

  import ElixirDrops.FeatureHelpers

  alias ElixirDrops.Drops.Drop

  @moduletag :feature

  describe "visitor sees authentication options" do
    test "visitor sees sign in button on homepage", %{conn: conn} do
      conn
      |> visit(~p"/")
      # Should see GitHub sign-in option
      |> assert_has("a", text: "Sign in with GitHub")
      # Should be a proper link to auth endpoint
      |> assert_has("a[href*='/auth/github']")
    end

    test "visitor sees create post button that triggers sign-in popup", %{conn: conn} do
      conn
      |> visit(~p"/")
      # Should see create post button for unauthenticated users
      |> assert_has("#create-post-button", text: "Create Post")

      # Click should trigger sign-in popup, not navigation
      |> click("#create-post-button")
      |> wait_for_element("#signin-popup-message", timeout: 3000)
      |> assert_has("#signin-popup-message")
      |> assert_has("p", text: "Take a moment to sign in to continue on ElixirDrops!")
    end
  end

  describe "visitor cannot access protected routes" do
    setup do
      user = user_fixture(%{github_id: 12_345, github_username: "testuser"})

      drop =
        drop_fixture(%Drop{}, user, %{
          title: "Protected Drop",
          body: "def protected, do: :content"
        })

      %{user: user, drop: drop}
    end

    test "visitor cannot access profile page", %{conn: conn} do
      conn
      |> visit(~p"/profile")
      # Should redirect to homepage with flash message
      |> assert_path("/")
      |> assert_has("main", text: "You must log in to access this page")
    end

    test "visitor cannot access drop creation page", %{conn: conn} do
      conn
      |> visit(~p"/drops/new")
      # Should redirect to homepage with flash message
      |> assert_path("/")
      |> assert_has("main", text: "You must log in to access this page")
    end

    test "visitor cannot access drop edit page", %{conn: conn, drop: drop} do
      conn
      |> visit(~p"/drops/#{drop.short_id}/edit")
      # Should redirect to homepage with flash message
      |> assert_path("/")
      |> assert_has("main", text: "You must log in to access this page")
    end

    test "visitor gets appropriate flash messages for protected routes", %{conn: conn} do
      conn
      |> visit(~p"/profile")
      |> assert_path("/")
      # Should see clear explanation of why redirect happened
      |> assert_has("[data-phx-live-flash]", text: "You must log in")
    end
  end

  describe "visitor can browse public content" do
    setup do
      user = user_fixture(%{github_id: 67_890, github_username: "creator"})

      public_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Public Drop Content",
          body: "def public_content, do: :viewable"
        })

      %{user: user, public_drop: public_drop}
    end

    test "visitor can browse homepage and view drops", %{
      conn: conn,
      public_drop: public_drop
    } do
      conn
      |> visit(~p"/")
      # Should see all public drops
      |> assert_has("main", text: public_drop.title)
      |> assert_has(".drop-card", text: "Public Drop Content")

      # Should be able to view individual drops
      |> click(".drop-card", text: public_drop.title)
      |> assert_path("/drops/#{public_drop.short_id}")
      |> assert_has("h1", text: public_drop.title)
      |> assert_has("pre code", text: "def public_content")
    end

    test "visitor sees limited UI without authentication features", %{conn: conn} do
      conn
      |> visit(~p"/")
      # Should NOT see user-specific elements
      |> refute_has("a[href='/profile']")
      |> refute_has("button", text: "Sign out")

      # Should see sign-in call-to-action
      |> assert_has("a", text: "Sign in with GitHub")
      |> assert_has("#create-post-button", text: "Create Post")
    end
  end

  describe "visitor sign-in popup JavaScript interactions" do
    test "sign-in popup can be dismissed with escape key", %{conn: conn} do
      conn
      |> visit(~p"/")
      |> click("#create-post-button")
      |> assert_has("#signin-popup-message")
      |> assert_has("p", text: "Take a moment to sign in to continue on ElixirDrops!")

      # Press Escape to dismiss popup
      |> press_key("Escape")
      |> wait_for(time: 1)
      # Popup should be hidden
      |> refute_has("#signin-popup-message")
    end

    test "sign-in popup can be dismissed by clicking outside", %{conn: conn} do
      conn
      |> visit(~p"/")
      |> click("#create-post-button")
      |> assert_has("#signin-popup-message")

      # Click outside the popup (on the backdrop/overlay)
      |> click(".modal-backdrop")
      |> wait_for(time: 1)
      # Popup should be hidden
      |> refute_has("#signin-popup-message")
    end

    test "sign-in popup has close button", %{conn: conn} do
      conn
      |> visit(~p"/")
      |> click("#create-post-button")
      |> assert_has("#signin-popup-message")

      # Click the close button (X)
      |> click("#signin-popup-message .close-button")
      |> wait_for(time: 1)
      # Popup should be hidden
      |> refute_has("#signin-popup-message")
    end

    test "multiple popup interactions work correctly", %{conn: conn} do
      conn
      |> visit(~p"/")
      # Open popup
      |> click("#create-post-button")
      |> assert_has("#signin-popup-message")

      # Close with Escape
      |> press_key("Escape")
      |> refute_has("#signin-popup-message")

      # Open popup again
      |> click("#create-post-button")
      |> assert_has("#signin-popup-message")

      # Close by clicking outside
      |> click(".modal-backdrop")
      |> refute_has("#signin-popup-message")
    end
  end

  describe "visitor completes sign-in flow" do
    setup do
      user = user_fixture(%{github_id: 11_111, github_username: "newsignin"})
      %{user: user}
    end

    test "visitor can sign in via dev auth", %{conn: conn, user: user} do
      conn
      |> visit(~p"/")
      |> assert_has("a", text: "Sign in with GitHub")

      # Use dev auth to simulate GitHub OAuth
      |> sign_in_user(user)
      |> assert_path("/")

      # Should see authenticated user state
      |> assert_has("main", text: user.github_username)
      |> refute_has("a", text: "Sign in with GitHub")
    end

    test "user avatar and username appear after sign in", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Should see user avatar/profile elements
      |> assert_has("nav", text: user.github_username)
      |> assert_has("nav", text: "newsignin")

      # Should see authenticated navigation options
      |> assert_has("a[href='/profile']")
    end

    test "sign out functionality works", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")
      |> assert_has("nav", text: user.github_username)

      # Click sign out
      |> click("a", text: "Sign out")
      |> assert_path("/")

      # Should return to unauthenticated state
      |> refute_has("nav", text: user.github_username)
      |> assert_has("a", text: "Sign in with GitHub")
    end

    test "session persists across page refreshes", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")
      |> assert_has("nav", text: user.github_username)

      # Refresh the page
      |> visit(~p"/")
      # User should still be signed in
      |> assert_has("nav", text: user.github_username)
      |> refute_has("a", text: "Sign in with GitHub")
    end
  end

  describe "post-authentication user experience" do
    setup do
      user = user_fixture(%{github_id: 22_222, github_username: "authenticated"})
      %{user: user}
    end

    test "authenticated user can access previously protected routes", %{
      conn: conn,
      user: user
    } do
      conn
      |> sign_in_user(user)

      # Can now access profile
      |> visit(~p"/profile")
      |> assert_path("/profile")
      |> assert_has("h1", text: "Your Drops")

      # Can access drop creation
      |> visit(~p"/drops/new")
      |> assert_path("/drops/new")
      |> assert_has("h1", text: "Share Code")
    end

    test "authenticated user sees enhanced UI elements", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Should see user-specific navigation
      |> assert_has("a[href='/profile']", text: "Profile")
      |> assert_has("button", text: "Sign out")

      # Create post button should navigate, not show popup
      |> click("#create-post-button")
      |> assert_path("/drops/new")
      |> refute_has("#signin-popup-message")
    end

    test "authenticated user maintains session across different pages", %{
      conn: conn,
      user: user
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")
      |> assert_has("nav", text: user.github_username)

      # Navigate to profile
      |> visit(~p"/profile")
      |> assert_has("nav", text: user.github_username)

      # Navigate to drop creation
      |> visit(~p"/drops/new")
      |> assert_has("nav", text: user.github_username)

      # Return to homepage
      |> visit(~p"/")
      |> assert_has("nav", text: user.github_username)
    end
  end

  describe "authorization and ownership checks" do
    setup do
      owner = user_fixture(%{github_id: 33_333, github_username: "owner"})
      other_user = user_fixture(%{github_id: 44_444, github_username: "otheruser"})

      owned_drop =
        drop_fixture(%Drop{}, owner, %{
          title: "Owner's Drop",
          body: "def owned, do: :mine"
        })

      %{owner: owner, other_user: other_user, owned_drop: owned_drop}
    end

    test "only drop owner sees edit button", %{
      conn: conn,
      owner: owner,
      other_user: other_user,
      owned_drop: owned_drop
    } do
      # Owner should see edit button
      conn
      |> sign_in_user(owner)
      |> visit("/d/#{owned_drop.short_id}")
      |> assert_has("a", text: "Edit")

      # Other user should NOT see edit button
      conn
      |> sign_in_user(other_user)
      |> visit("/d/#{owned_drop.short_id}")
      |> refute_has("a", text: "Edit")
    end

    test "non-owners cannot access edit URLs directly", %{
      conn: conn,
      other_user: other_user,
      owned_drop: owned_drop
    } do
      conn
      |> sign_in_user(other_user)
      |> visit(~p"/drops/#{owned_drop.short_id}/edit")
      # Should redirect away from edit page
      |> assert_path("/")
      |> assert_has("main", text: "You can only edit your own drops")
    end

    test "edit URLs for non-owned drops show appropriate error", %{
      conn: conn,
      other_user: other_user,
      owned_drop: owned_drop
    } do
      conn
      |> sign_in_user(other_user)
      |> visit(~p"/drops/#{owned_drop.short_id}/edit")
      |> assert_path("/")
      # Should see clear authorization message
      |> assert_has("[data-phx-live-flash]", text: "You can only edit your own drops")
    end
  end
end
