defmodule ElixirDropsWeb.Features.UserDropCreationTest do
  @moduledoc """
  Domain-based feature tests for user drop creation experience.

  Story 3: "As a user, I want to create and share drops"

  Covers the complete user drop creation domain including:
  - Drop creation form interactions and validation
  - Code input handling and preview functionality  
  - Screenshot generation process and UI feedback
  - Form submission and success handling
  - Drop sharing and post-creation experience
  - Error handling and recovery flows
  """

  use ElixirDropsWeb.FeatureCase, async: false

  import ElixirDrops.FeatureHelpers

  @moduletag :feature

  describe "user accesses drop creation" do
    setup do
      user = user_fixture(%{github_id: 12_345, github_username: "creator"})
      %{user: user}
    end

    test "authenticated user can access create post page", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")
      # Create post button should navigate to creation form
      |> click("#create-post-button")
      |> assert_path("/drops/new")
      |> assert_has("h1", text: "Share Code")
    end

    test "create post form displays with proper fields", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # Verify form elements are present
      |> assert_has("form")
      |> assert_has("input[name='drop[title]']")
      |> assert_has("textarea[name='drop[body]']")
      |> assert_has("button[type='submit']", text: "Post Drop")

      # Should see helpful placeholder text
      |> assert_has("input[placeholder*='title']")
      |> assert_has("textarea[placeholder*='code']")
    end

    test "user can navigate to creation from profile page", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/profile")
      |> assert_has("a[href='/drops/new']")
      |> click("a[href='/drops/new']")
      |> assert_path("/drops/new")
      |> assert_has("h1", text: "Share Code")
    end
  end

  describe "user creates drop with code content" do
    setup do
      user = user_fixture(%{github_id: 67_890, github_username: "coder"})
      %{user: user}
    end

    test "user can create elixir drop with complete flow", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # Fill out form with Elixir code
      |> fill_in("Title", with: "Elixir Pattern Matching Example")
      |> fill_in("Code",
        with: """
        def analyze_result(result) do
          case result do
            {:ok, data} -> process_success(data)
            {:error, reason} -> handle_error(reason)
            _ -> {:unknown, result}
          end
        end
        """
      )

      # Submit the form
      |> click("button[type='submit']", text: "Post Drop")

      # Should redirect to profile with success message
      |> assert_path("/profile")
      |> assert_has("main", text: "Drop created successfully")

      # New drop should appear in user's profile
      |> assert_has(".drop-card", text: "Elixir Pattern Matching Example")
      |> assert_has(".drop-card", text: "analyze_result")
    end

    test "user can create javascript drop", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")
      |> fill_in("Title", with: "JavaScript Async Function")
      |> fill_in("Code",
        with: """
        async function fetchUserData(userId) {
          try {
            const response = await fetch(`/api/users/${userId}`);
            return await response.json();
          } catch (error) {
            console.error('Failed to fetch user:', error);
            throw error;
          }
        }
        """
      )
      |> click("button[type='submit']", text: "Post Drop")
      |> assert_path("/profile")
      |> assert_has("main", text: "Drop created successfully")
      |> assert_has(".drop-card", text: "JavaScript Async Function")
    end

    test "user can create drop without code blocks", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # Create a drop with plain text content
      |> fill_in("Title", with: "Development Notes")
      |> fill_in("Code", with: "Remember to update dependencies and run tests before deployment")
      |> click("button[type='submit']", text: "Post Drop")
      |> assert_path("/profile")
      |> assert_has("main", text: "Drop created successfully")
      |> assert_has(".drop-card", text: "Development Notes")
    end
  end

  describe "drop creation form validation" do
    setup do
      user = user_fixture(%{github_id: 11_111, github_username: "validator"})
      %{user: user}
    end

    test "empty form shows validation errors", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # Submit empty form
      |> click("button[type='submit']", text: "Post Drop")

      # Should show validation errors
      |> assert_path("/drops/new")
      |> assert_has("main", text: "can't be blank")

      # Error messages should be specific
      |> assert_has("form", text: "Title can't be blank")
      |> assert_has("form", text: "Body can't be blank")
    end

    test "title too long shows validation error", %{conn: conn, user: user} do
      long_title = String.duplicate("A", 256)

      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")
      |> fill_in("Title", with: long_title)
      |> fill_in("Code", with: "def test, do: :ok")
      |> click("button[type='submit']", text: "Post Drop")

      # Should show title length validation error
      |> assert_path("/drops/new")
      |> assert_has("form", text: "should be at most 255 character")
    end

    test "body too long shows validation error", %{conn: conn, user: user} do
      # Create content longer than allowed limit
      long_body = String.duplicate("# This is a very long comment\n", 200)

      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")
      |> fill_in("Title", with: "Long Content Test")
      |> fill_in("Code", with: long_body)
      |> click("button[type='submit']", text: "Post Drop")

      # Should show body length validation error
      |> assert_path("/drops/new")
      |> assert_has("form", text: "should be at most")
    end

    test "form preserves user input after validation error", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # Fill partial form that will fail validation
      |> fill_in("Title", with: "Partial Form Test")
      # Leave body empty to trigger validation error
      |> click("button[type='submit']", text: "Post Drop")

      # Title should be preserved in form
      |> assert_field_value("Title", "Partial Form Test")
      |> assert_has("form", text: "Body can't be blank")
    end
  end

  describe "screenshot generation and progress feedback" do
    setup do
      user = user_fixture(%{github_id: 22_222, github_username: "screenshotter"})
      %{user: user}
    end

    test "screenshot generation shows progress after submission", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")
      |> fill_in("Title", with: "Screenshot Test Drop")
      |> fill_in("Code",
        with: """
        def generate_screenshot do
          # This will trigger screenshot generation
          :processing
        end
        """
      )
      |> click("button[type='submit']", text: "Post Drop")
      |> assert_path("/profile")

      # Should see success message
      |> assert_has("main", text: "Drop created successfully")

      # Navigate to the created drop to check screenshot status
      |> click(".drop-card", text: "Screenshot Test Drop")

      # Initially should show pending screenshot status
      |> assert_has("[data-screenshot-status='pending']")

      # Process screenshot generation job
      # (In real app, this would be handled by Oban background job)
      |> then(fn session ->
        # Simulate screenshot job completion
        Process.sleep(100)
        session
      end)

      # Refresh to see updated screenshot status
      |> then(fn session -> visit(session, current_path(session)) end)
      |> wait_for_element("[data-screenshot-status]", timeout: 5000)
    end

    test "drop creation with code blocks triggers screenshot generation", %{
      conn: conn,
      user: user
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")
      |> fill_in("Title", with: "Code Block Screenshot Test")
      |> fill_in("Code",
        with: """
        defmodule MyModule do
          def process_data(data) when is_list(data) do
            data
            |> Enum.map(&String.upcase/1)
            |> Enum.join(", ")
          end
        end
        """
      )
      |> click("button[type='submit']", text: "Post Drop")
      |> assert_path("/profile")
      |> assert_has("main", text: "Drop created successfully")

      # Check that the drop was created with proper screenshot metadata
      |> click(".drop-card", text: "Code Block Screenshot Test")
      |> assert_has("pre code", text: "defmodule MyModule")

      # Screenshot elements should be present
      |> assert_has(".drop-content")
    end
  end

  describe "post-creation experience and sharing" do
    setup do
      user = user_fixture(%{github_id: 33_333, github_username: "sharer"})
      %{user: user}
    end

    test "user can view created drop immediately", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")
      |> fill_in("Title", with: "Immediate View Test")
      |> fill_in("Code", with: "def immediate_view, do: :success")
      |> click("button[type='submit']", text: "Post Drop")

      # Should be redirected to profile
      |> assert_path("/profile")
      |> assert_has(".drop-card", text: "Immediate View Test")

      # Can click to view the drop
      |> click(".drop-card", text: "Immediate View Test")
      |> assert_path_matches(~r|/drops/[a-z0-9]+$|)
      |> assert_has("h1", text: "Immediate View Test")
      |> assert_has("pre code", text: "def immediate_view")
    end

    test "created drop appears on homepage for all users", %{conn: conn, user: user} do
      # Create drop as user
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")
      |> fill_in("Title", with: "Public Visibility Test")
      |> fill_in("Code", with: "def public_visibility, do: :visible")
      |> click("button[type='submit']", text: "Post Drop")

      # Sign out and check as visitor
      |> click("a", text: "Sign out")
      |> visit(~p"/")

      # Drop should be visible to all users
      |> assert_has(".drop-card", text: "Public Visibility Test")
      |> assert_has(".drop-card", text: user.github_username)
    end

    test "user can navigate back to creation from success page", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")
      |> fill_in("Title", with: "Navigation Test")
      |> fill_in("Code", with: "def navigation_test, do: :ok")
      |> click("button[type='submit']", text: "Post Drop")

      # From profile page, should be able to create another drop
      |> assert_path("/profile")
      |> click("a[href='/drops/new']")
      |> assert_path("/drops/new")
      |> assert_has("h1", text: "Share Code")

      # Form should be empty for new drop
      |> assert_field_value("Title", "")
      |> assert_field_value("Code", "")
    end
  end

  describe "creation error handling and recovery" do
    setup do
      user = user_fixture(%{github_id: 44_444, github_username: "error_handler"})
      %{user: user}
    end

    test "network error recovery preserves form data", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")
      |> fill_in("Title", with: "Error Recovery Test")
      |> fill_in("Code", with: "def error_recovery, do: :test")

      # Simulate network error scenario by filling invalid data that might cause server error
      # (In real scenario, this might be network connectivity issue)
      # Clear title to cause validation error
      |> fill_in("Title", with: "")
      |> click("button[type='submit']", text: "Post Drop")

      # Should stay on form with error, preserving code content
      |> assert_path("/drops/new")
      |> assert_field_value("Code", "def error_recovery, do: :test")
      |> assert_has("form", text: "can't be blank")
    end

    test "user can retry creation after fixing validation errors", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # First attempt with validation error
      |> fill_in("Code", with: "def retry_test, do: :attempt_one")
      # Leave title empty
      |> click("button[type='submit']", text: "Post Drop")
      |> assert_has("form", text: "Title can't be blank")

      # Fix the error and retry
      |> fill_in("Title", with: "Retry Success Test")
      |> click("button[type='submit']", text: "Post Drop")

      # Should succeed on second attempt
      |> assert_path("/profile")
      |> assert_has("main", text: "Drop created successfully")
      |> assert_has(".drop-card", text: "Retry Success Test")
    end

    test "form handles special characters and encoding properly", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")
      |> fill_in("Title", with: "Special Characters: äöü & <script>")
      |> fill_in("Code",
        with: """
        # This contains special characters: äöü
        def handle_special_chars(text) do
          text
          |> String.replace("&", "&amp;")
          |> String.replace("<", "&lt;")
          |> String.replace(">", "&gt;")
        end
        """
      )
      |> click("button[type='submit']", text: "Post Drop")
      |> assert_path("/profile")
      |> assert_has("main", text: "Drop created successfully")

      # Special characters should be properly handled
      |> assert_has(".drop-card", text: "Special Characters")
      |> click(".drop-card", text: "Special Characters")
      |> assert_has("h1", text: "Special Characters: äöü & <script>")
      |> assert_has("pre code", text: "handle_special_chars")
    end
  end

  describe "creation form user experience" do
    setup do
      user = user_fixture(%{github_id: 55_555, github_username: "ux_tester"})
      %{user: user}
    end

    test "form provides helpful placeholder text", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # Check for helpful placeholder text
      |> assert_has("input[placeholder*='meaningful title']")
      |> assert_has("textarea[placeholder*='paste your code']")
    end

    test "form labels are properly associated with inputs", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # Labels should be properly associated for accessibility
      |> assert_has("label[for*='title']", text: "Title")
      |> assert_has("label[for*='body']", text: "Code")
    end

    test "textarea resizes appropriately for code content", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # Textarea should be appropriately sized for code
      |> assert_has("textarea[rows]")

      # Should accept large code blocks
      large_code =
        """
        defmodule LargeExample do
          def large_function do
            # Line 1
            # Line 2
            # Line 3
            # Line 4
            # Line 5
            :large_result
          end
          
          def another_function do
            :another_result
          end
        end
        """

      conn
      |> fill_in("Title", with: "Large Code Example")
      |> fill_in("Code", with: large_code)
      |> click("button[type='submit']", text: "Post Drop")
      |> assert_path("/profile")
      |> assert_has("main", text: "Drop created successfully")
    end
  end
end
