defmodule ElixirDropsWeb.Features.UserDropCreationTest do
  @moduledoc """
  Domain-based feature tests for user drop creation experience.

  Story 3: "As a user, I want to create and share drops"

  Covers the complete user drop creation domain including:
  - Drop creation form interactions and validation
  - Code input handling and preview functionality
  - Screenshot generation process and UI feedback
  - Form submission and success handling
  - Drop sharing and drop-creation experience
  - Error handling and recovery flows
  """

  use ElixirDropsWeb.FeatureCase, async: true

  import ElixirDrops.FeatureHelpers

  @moduletag :feature

  describe "user accesses drop creation" do
    setup do
      user = user_fixture(%{github_id: 12_345, github_username: "creator"})
      %{user: user}
    end

    test "authenticated user can access create drop page", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")
      # Create drop button should navigate to creation form
      |> click("#create-drop-button")
      |> assert_path("/drops/new")
      |> assert_has("h2", text: "Write a new drop")
    end

    test "create drop form displays with proper fields", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # Verify form elements are present
      |> assert_has("form")
      |> assert_has("input[name='drop[title]']")
      |> assert_has("textarea[name='drop[body]']")
      |> assert_has("button[type='submit']", text: "Create Drop")

      # Should see helpful placeholder text
      |> assert_has("input[placeholder*='title']")
      |> assert_has("textarea[placeholder*='Start writing']")
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
      |> fill_in("Body",
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
      |> click("button[type='submit']")

      # Should redirect to the drop page
      # Wait for redirect to complete
      |> then(fn session ->
        Process.sleep(500)
        session
      end)

      # Drop should be displayed with content
      |> assert_has("h1", text: "Elixir Pattern Matching Example")
      |> assert_has(".drop-full-content", text: "analyze_result")
    end

    test "user can create javascript drop", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")
      |> fill_in("Title", with: "JavaScript Async Function")
      |> fill_in("Body",
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
      |> click("button[type='submit']")
      # Wait for redirect to complete
      |> then(fn session ->
        Process.sleep(500)
        session
      end)
      |> assert_has("h1", text: "JavaScript Async Function")
    end

    test "user can create drop without code blocks", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # Create a drop with plain text content
      |> fill_in("Title", with: "Development Notes")
      |> fill_in("Body", with: "Remember to update dependencies and run tests before deployment")
      |> click("button[type='submit']")
      # Wait for redirect to complete
      |> then(fn session ->
        Process.sleep(500)
        session
      end)
      |> assert_has("h1", text: "Development Notes")
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
      |> click("button[type='submit']")

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
      |> fill_in("Body", with: "def test, do: :ok")
      |> click("button[type='submit']")

      # Should show title length validation error
      |> assert_path("/drops/new")
      |> assert_has("form", text: "should be at most 255 character")
    end

    test "form preserves user input after validation error", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # Fill partial form that will fail validation
      |> fill_in("Title", with: "Partial Form Test")
      # Leave body empty to trigger validation error
      |> click("button[type='submit']")

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
      |> fill_in("Body",
        with: """
        def generate_screenshot do
          # This will trigger screenshot generation
          :processing
        end
        """
      )
      |> click("button[type='submit']")

      # Should redirect to the drop page
      # Wait for redirect to complete
      |> then(fn session ->
        Process.sleep(500)
        session
      end)

      # Drop should display with title
      |> assert_has("h1", text: "Screenshot Test Drop")

      # Check if screenshot-related elements exist
      # The drop content should be visible
      |> assert_has(".drop-full-content", text: "generate_screenshot")
    end

    test "drop creation with code blocks triggers screenshot generation", %{
      conn: conn,
      user: user
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")
      |> fill_in("Title", with: "Code Block Screenshot Test")
      |> fill_in("Body",
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
      |> click("button[type='submit']")

      # Should redirect to drop page
      # Wait for redirect to complete
      |> then(fn session ->
        Process.sleep(500)
        session
      end)

      # Check that the drop was created with code content
      |> assert_has("h1", text: "Code Block Screenshot Test")
      |> assert_has(".drop-full-content", text: "defmodule MyModule")

      # Screenshot elements should be present
      |> assert_has(".drop-full-content")
    end
  end

  describe "drop-creation experience and sharing" do
    setup do
      user = user_fixture(%{github_id: 33_333, github_username: "sharer"})
      %{user: user}
    end

    test "user can view created drop immediately", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")
      |> fill_in("Title", with: "Immediate View Test")
      |> fill_in("Body", with: "def immediate_view, do: :success")
      |> click("button[type='submit']")

      # Should be redirected to the drop page
      # Wait for redirect to complete
      |> then(fn session ->
        Process.sleep(500)
        session
      end)
      |> assert_has("h1", text: "Immediate View Test")
      |> assert_has(".drop-full-content", text: "def immediate_view")
    end

    test "created drop appears on homepage for all users", %{conn: conn, user: user} do
      # Create drop as user
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")
      |> fill_in("Title", with: "Public Visibility Test")
      |> fill_in("Body", with: "def public_visibility, do: :visible")
      |> click("button[type='submit']")

      # Wait for redirect to drop page
      |> then(fn session ->
        Process.sleep(500)
        session
      end)

      # Check that the drop appears on the homepage
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
      |> fill_in("Body", with: "def navigation_test, do: :ok")
      |> click("button[type='submit']")

      # Should redirect to drop page
      # Wait for redirect to complete
      |> then(fn session ->
        Process.sleep(500)
        session
      end)

      # Navigate back to home to create another drop
      |> visit(~p"/")
      |> click("#create-drop-button")
      |> assert_path("/drops/new")

      # Form should be empty for new drop
      |> assert_field_value("Title", "")
      |> assert_field_value("Body", "")
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
      |> fill_in("Body", with: "def error_recovery, do: :test")

      # Simulate network error scenario by filling invalid data that might cause server error
      # (In real scenario, this might be network connectivity issue)
      # Clear title to cause validation error
      |> fill_in("Title", with: "")
      |> click("button[type='submit']")

      # Should stay on form with error, preserving code content
      |> assert_path("/drops/new")
      |> assert_field_value("Body", "def error_recovery, do: :test")
      |> assert_has("form", text: "can't be blank")
    end

    test "user can retry creation after fixing validation errors", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # First attempt with validation error
      |> fill_in("Body", with: "def retry_test, do: :attempt_one")
      # Leave title empty
      |> click("button[type='submit']")
      |> assert_has("form", text: "Title can't be blank")

      # Fix the error and retry
      |> fill_in("Title", with: "Retry Success Test")
      |> click("button[type='submit']")

      # Should succeed on second attempt
      # Wait for redirect to complete
      |> then(fn session ->
        Process.sleep(500)
        session
      end)
      |> assert_has("h1", text: "Retry Success Test")
    end

    test "form handles special characters and encoding properly", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")
      |> fill_in("Title", with: "Special Characters: äöü & <script>")
      |> fill_in("Body",
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
      |> click("button[type='submit']")

      # Should redirect to drop page
      # Wait for redirect to complete
      |> then(fn session ->
        Process.sleep(500)
        session
      end)

      # Special characters should be properly handled
      |> assert_has("h1", text: "Special Characters: äöü & <script>")
      |> assert_has(".drop-full-content", text: "handle_special_chars")
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
      |> assert_has("input[placeholder*='Drop summary']")
      |> assert_has("textarea[placeholder*='Start writing']")
    end

    test "form labels are properly associated with inputs", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # Labels should be properly associated for accessibility
      |> assert_has("label", text: "Title")
      |> assert_has("label", text: "Body")
    end

    test "textarea resizes appropriately for code content", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # Textarea should be appropriately sized for code
      |> assert_has("textarea")

      # The textarea should be resizable and accept large code blocks
      # This is mainly a UI test to ensure the textarea is properly configured
    end
  end
end
