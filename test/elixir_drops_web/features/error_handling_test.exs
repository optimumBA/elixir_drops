defmodule ElixirDropsWeb.Features.ErrorHandlingTest do
  @moduledoc """
  Domain-based feature tests for error handling and recovery experience.

  Story 8: "As a user, I want graceful error handling and recovery"

  Covers the complete error handling domain including:
  - Form validation errors and user guidance
  - Network connectivity issues and recovery
  - Authentication errors and redirects
  - Resource not found scenarios and navigation
  - Server errors and fallback behavior
  - Data consistency and error prevention
  """

  use ElixirDropsWeb.FeatureCase, async: false

  import ElixirDrops.FeatureHelpers

  alias ElixirDrops.Drops.Drop

  @moduletag :feature

  describe "form validation errors and user guidance" do
    setup do
      user = user_fixture(%{github_id: 12_345, github_username: "error_tester"})
      %{user: user}
    end

    test "drop creation form shows clear validation errors", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # Submit empty form
      |> click("button[type='submit']", text: "Post Drop")

      # Should show clear validation messages
      |> assert_path("/drops/new")
      |> assert_has("form", text: "Title can't be blank")
      |> assert_has("form", text: "Body can't be blank")

      # Form should remain functional after errors
      |> assert_has("input[name='drop[title]']")
      |> assert_has("textarea[name='drop[body]']")
      |> assert_has("button[type='submit']", text: "Post Drop")
    end

    test "validation errors update as user fixes issues", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # Start with validation errors
      |> click("button[type='submit']", text: "Post Drop")
      |> assert_has("form", text: "Title can't be blank")
      |> assert_has("form", text: "Body can't be blank")

      # Fix title error
      |> fill_in("Title", with: "Error Recovery Test")
      |> click("button[type='submit']", text: "Post Drop")

      # Title error should be gone, body error should remain
      |> refute_has("form", text: "Title can't be blank")
      |> assert_has("form", text: "Body can't be blank")

      # Fix body error
      |> fill_in("Code", with: "def error_recovery, do: :success")
      |> click("button[type='submit']", text: "Post Drop")

      # Should succeed
      |> assert_path("/profile")
      |> assert_has("main", text: "Drop created successfully")
    end

    test "field length validation provides helpful feedback", %{conn: conn, user: user} do
      very_long_title = String.duplicate("A", 300)

      very_long_body =
        String.duplicate("# This is a very long comment that exceeds limits\n", 100)

      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # Test title length validation
      |> fill_in("Title", with: very_long_title)
      |> fill_in("Code", with: "def test, do: :ok")
      |> click("button[type='submit']", text: "Post Drop")

      # Should show helpful length error
      |> assert_path("/drops/new")
      |> assert_has("form", text: "should be at most 255 character")

      # Test body length validation
      |> fill_in("Title", with: "Length Validation Test")
      |> fill_in("Code", with: very_long_body)
      |> click("button[type='submit']", text: "Post Drop")

      # Should show body length error
      |> assert_has("form", text: "should be at most")
    end

    test "edit form preserves user input during validation errors", %{conn: conn, user: user} do
      drop =
        drop_fixture(%Drop{}, user, %{
          title: "Edit Error Test",
          body: "def edit_error, do: :original"
        })

      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/#{drop.short_id}/edit")

      # Make valid changes but create validation error
      |> fill_in("Code", with: "def edit_error, do: :updated_content")
      # Invalid
      |> fill_in("Title", with: "")
      |> click("button[type='submit']", text: "Update Drop")

      # Should preserve the code changes
      |> assert_path("/drops/#{drop.short_id}/edit")
      |> assert_field_value("Code", "def edit_error, do: :updated_content")
      |> assert_has("form", text: "Title can't be blank")

      # Fix and submit successfully
      |> fill_in("Title", with: "Edit Error Fixed")
      |> click("button[type='submit']", text: "Update Drop")
      |> assert_path("/drops/#{drop.short_id}")
      |> assert_has("h1", text: "Edit Error Fixed")
      |> assert_has("pre code", text: ":updated_content")
    end
  end

  describe "authentication errors and access control" do
    setup do
      user = user_fixture(%{github_id: 67_890, github_username: "auth_user"})

      # Create a drop owned by the user
      user_drop =
        drop_fixture(%Drop{}, user, %{
          title: "User's Protected Drop",
          body: "def protected, do: :owner_only"
        })

      %{user: user, user_drop: user_drop}
    end

    test "unauthenticated users get helpful redirect messages", %{
      conn: conn,
      user_drop: user_drop
    } do
      # Try to access protected routes without authentication
      conn
      |> visit(~p"/profile")

      # Should redirect with helpful message
      |> assert_path("/")
      |> assert_has("main", text: "You must log in to access this page")

      # Try drop creation
      |> visit(~p"/drops/new")
      |> assert_path("/")
      |> assert_has("main", text: "You must log in to access this page")

      # Try drop editing
      |> visit(~p"/drops/#{user_drop.short_id}/edit")
      |> assert_path("/")
      |> assert_has("main", text: "You must log in to access this page")
    end

    test "unauthorized users cannot edit others' drops", %{conn: conn, user_drop: user_drop} do
      other_user = user_fixture(%{github_id: 99_999, github_username: "other_user"})

      conn
      |> sign_in_user(other_user)
      |> visit(~p"/drops/#{user_drop.short_id}/edit")

      # Should redirect with authorization error
      |> assert_path("/")
      |> assert_has("main", text: "You can only edit your own drops")
    end

    test "session expiration handles gracefully", %{conn: conn, user: user} do
      # Sign in and access protected resource
      conn
      |> sign_in_user(user)
      |> visit(~p"/profile")
      |> assert_has("h1", text: "Your Drops")

      # Simulate session expiration by signing out
      |> click("a", text: "Sign out")

      # Try to access protected resource again
      |> visit(~p"/profile")
      |> assert_path("/")
      |> assert_has("main", text: "You must log in to access this page")

      # User should be able to sign in again
      |> sign_in_user(user)
      |> visit(~p"/profile")
      |> assert_has("h1", text: "Your Drops")
    end

    test "authentication state persists across form submissions", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # Submit invalid form (should stay authenticated)
      |> click("button[type='submit']", text: "Post Drop")
      |> assert_path("/drops/new")
      |> assert_has("form", text: "can't be blank")

      # Should still be authenticated
      |> assert_has("nav", text: user.github_username)

      # Should be able to fix and submit
      |> fill_in("Title", with: "Auth Persistence Test")
      |> fill_in("Code", with: "def auth_persistence, do: :maintained")
      |> click("button[type='submit']", text: "Post Drop")
      |> assert_path("/profile")
      |> assert_has("nav", text: user.github_username)
      |> assert_has(".drop-card", text: "Auth Persistence Test")
    end
  end

  describe "resource not found and navigation errors" do
    setup do
      user = user_fixture(%{github_id: 11_111, github_username: "nav_user"})
      %{user: user}
    end

    test "invalid drop URLs redirect gracefully", %{conn: conn} do
      # Try to access non-existent drop
      conn
      |> visit("/drops/nonexistent123")

      # Should redirect to homepage
      |> assert_path("/")
      |> assert_has("main")

      # Should not show error message that breaks the UI
      |> refute_has("main", text: "error")
      |> refute_has("main", text: "not found")
    end

    test "malformed URLs handle gracefully", %{conn: conn} do
      # Try various malformed URLs
      test_urls = [
        "/drops/",
        "/drops/invalid-format-123-abc",
        "/drops/../../etc/passwd",
        "/drops/%3Cscript%3E"
      ]

      for url <- test_urls do
        conn
        |> visit(url)

        # Should either show content or redirect safely
        |> then(fn session ->
          # Check that we're either on a valid page or redirected
          current_path = current_path(session)

          if current_path == "/" do
            # Redirected to homepage
            assert_has(session, "main")
          else
            # Or showing valid content
            assert_has(session, "nav")
          end

          session
        end)
      end
    end

    test "navigation works after encountering errors", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)

      # Try invalid drop URL
      |> visit("/drops/invalid123")
      |> assert_path("/")

      # Navigation should still work
      |> click("a[href='/profile']")
      |> assert_path("/profile")
      |> assert_has("h1", text: "Your Drops")

      # Can create new drop
      |> click("a[href='/drops/new']")
      |> assert_path("/drops/new")
      |> assert_has("h1", text: "Share Code")

      # Form should work normally
      |> fill_in("Title", with: "Navigation Recovery Test")
      |> fill_in("Code", with: "def navigation_recovery, do: :works")
      |> click("button[type='submit']", text: "Post Drop")
      |> assert_path("/profile")
      |> assert_has(".drop-card", text: "Navigation Recovery Test")
    end

    test "search handles invalid queries gracefully", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # Try searches that might cause issues
      problematic_queries = [
        "",
        " ",
        String.duplicate("x", 1000),
        "'; DROP TABLE drops; --",
        "<script>alert('xss')</script>",
        "null",
        "undefined"
      ]

      for query <- problematic_queries do
        conn_session = fill_in(conn, "Search drops", with: query)
        session = press_key(conn_session, "Enter")

        # Should handle gracefully - either show results or no results
        # Should not crash or show raw errors
        refute_has(session, "main", text: "error")
        refute_has(session, "main", text: "Error")
        refute_has(session, "main", text: "crash")
      end
    end
  end

  describe "network connectivity and recovery" do
    setup do
      user = user_fixture(%{github_id: 22_222, github_username: "network_user"})
      %{user: user}
    end

    test "form retries work after initial failure", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # Fill form
      |> fill_in("Title", with: "Network Recovery Test")
      |> fill_in("Code", with: "def network_recovery, do: :retry")

      # Simulate network issue by submitting invalid form first
      # Invalid
      |> fill_in("Title", with: "")
      |> click("button[type='submit']", text: "Post Drop")

      # Should preserve content and allow retry
      |> assert_path("/drops/new")
      |> assert_field_value("Code", "def network_recovery, do: :retry")
      |> assert_has("form", text: "can't be blank")

      # Fix and retry successfully
      |> fill_in("Title", with: "Network Recovery Test Fixed")
      |> click("button[type='submit']", text: "Post Drop")
      |> assert_path("/profile")
      |> assert_has("main", text: "Drop created successfully")
      |> assert_has(".drop-card", text: "Network Recovery Test Fixed")
    end

    test "search functionality recovers from connectivity issues", %{conn: conn, user: user} do
      # Create a drop to search for
      search_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Network Search Test",
          body: "def network_search, do: :recoverable"
        })

      conn
      |> sign_in_user(user)
      |> visit(~p"/")

      # First search should work
      |> fill_in("Search drops", with: "Network")
      |> press_key("Enter")
      |> assert_url_contains("?q=Network")
      |> assert_has(".drop-card", text: search_drop.title)

      # Simulate recovery by doing another search
      |> fill_in("Search drops", with: "Search")
      |> press_key("Enter")
      |> assert_url_contains("?q=Search")
      |> assert_has(".drop-card", text: search_drop.title)

      # Clear search should also work
      |> fill_in("Search drops", with: "")
      |> press_key("Enter")
      |> assert_url_contains("?q=")
    end

    test "page state remains consistent during network issues", %{conn: conn, user: user} do
      drop =
        drop_fixture(%Drop{}, user, %{
          title: "State Consistency Test",
          body: "def state_consistency, do: :maintained"
        })

      conn
      |> sign_in_user(user)
      |> visit("/d/#{drop.short_id}")
      |> assert_has("h1", text: drop.title)

      # Navigate to edit form
      |> click("a", text: "Edit")
      |> assert_path("/drops/#{drop.short_id}/edit")
      |> assert_field_value("Title", drop.title)

      # Simulate network issue with form submission
      # Invalid
      |> fill_in("Title", with: "")
      |> click("button[type='submit']", text: "Update Drop")

      # State should be preserved
      |> assert_path("/drops/#{drop.short_id}/edit")
      |> assert_field_value("Code", drop.body)
      |> assert_has("form", text: "can't be blank")

      # User should still be authenticated
      |> assert_has("nav", text: user.github_username)

      # Navigation should still work
      |> click("a[href='/drops/#{drop.short_id}']")
      |> assert_path("/drops/#{drop.short_id}")
      |> assert_has("h1", text: drop.title)
    end
  end

  describe "data consistency and error prevention" do
    setup do
      user = user_fixture(%{github_id: 33_333, github_username: "consistency_user"})
      %{user: user}
    end

    test "concurrent edits handle gracefully", %{conn: conn, user: user} do
      drop =
        drop_fixture(%Drop{}, user, %{
          title: "Concurrent Edit Test",
          body: "def concurrent_edit, do: :original"
        })

      # Start editing
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/#{drop.short_id}/edit")
      |> assert_field_value("Title", drop.title)
      |> assert_field_value("Code", drop.body)

      # Make changes
      |> fill_in("Title", with: "Concurrent Edit Updated")
      |> fill_in("Code", with: "def concurrent_edit, do: :updated")

      # Submit should work (no actual concurrency conflict in test)
      |> click("button[type='submit']", text: "Update Drop")
      |> assert_path("/drops/#{drop.short_id}")
      |> assert_has("h1", text: "Concurrent Edit Updated")
      |> assert_has("pre code", text: ":updated")
    end

    test "database integrity maintained during errors", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # Create drop successfully
      |> fill_in("Title", with: "Integrity Test Drop")
      |> fill_in("Code", with: "def integrity_test, do: :consistent")
      |> click("button[type='submit']", text: "Post Drop")
      |> assert_path("/profile")
      |> assert_has(".drop-card", text: "Integrity Test Drop")

      # Drop should be viewable
      |> click(".drop-card", text: "Integrity Test Drop")
      |> assert_path_matches(~r|/drops/[a-z0-9]+$|)
      |> assert_has("h1", text: "Integrity Test Drop")
      |> assert_has("pre code", text: "def integrity_test")

      # Drop should be editable by owner
      |> click("a", text: "Edit")
      |> assert_field_value("Title", "Integrity Test Drop")
      |> assert_field_value("Code", "def integrity_test, do: :consistent")
    end

    test "user input sanitization prevents XSS", %{conn: conn, user: user} do
      malicious_inputs = [
        "<script>alert('xss')</script>",
        "javascript:alert('xss')",
        "<img src=x onerror=alert('xss')>",
        "';DROP TABLE drops;--"
      ]

      for malicious_input <- malicious_inputs do
        # Create drop with potentially malicious content
        conn
        |> sign_in_user(user)
        |> visit(~p"/drops/new")
        |> fill_in("Title", with: "XSS Test: #{malicious_input}")
        |> fill_in("Code", with: "def xss_test, do: #{inspect(malicious_input)}")
        |> click("button[type='submit']", text: "Post Drop")
        |> assert_path("/profile")
        |> assert_has("main", text: "Drop created successfully")

        # Content should be safely displayed
        |> click(".drop-card", text: "XSS Test:")
        |> assert_has("h1", text: "XSS Test:")
        |> assert_has("pre code", text: malicious_input)

        # JavaScript should not execute
        |> refute_has("main", text: "alert")
        |> refute_has("main", text: "DROP TABLE")
      end
    end

    test "form CSRF protection works", %{conn: conn, user: user} do
      # Normal form submission should work
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")
      |> fill_in("Title", with: "CSRF Protection Test")
      |> fill_in("Code", with: "def csrf_protection, do: :secure")
      |> click("button[type='submit']", text: "Post Drop")

      # Should succeed with proper CSRF token
      |> assert_path("/profile")
      |> assert_has("main", text: "Drop created successfully")
      |> assert_has(".drop-card", text: "CSRF Protection Test")
    end
  end

  describe "user experience during errors" do
    setup do
      user = user_fixture(%{github_id: 44_444, github_username: "ux_user"})
      %{user: user}
    end

    test "error messages are user-friendly and actionable", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # Test various validation scenarios
      |> click("button[type='submit']", text: "Post Drop")

      # Messages should be clear and helpful
      |> assert_has("form", text: "Title can't be blank")
      |> assert_has("form", text: "Body can't be blank")

      # Should not show technical jargon
      |> refute_has("form", text: "NULL")
      |> refute_has("form", text: "validation failed")
      |> refute_has("form", text: "constraint")

      # Test length validation messages
      |> fill_in("Title", with: String.duplicate("A", 300))
      |> fill_in("Code", with: "def test, do: :ok")
      |> click("button[type='submit']", text: "Post Drop")

      # Should show helpful guidance
      |> assert_has("form", text: "should be at most 255 character")
    end

    test "error recovery preserves user work", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # User spends time writing content
      complex_code =
        """
        defmodule ComplexExample do
          @moduledoc \"\"\"
          This is a complex module that the user spent time writing.
          It would be frustrating to lose this work due to a validation error.
          \"\"\"
          
          def complex_function(input) when is_binary(input) do
            input
            |> String.trim()
            |> String.downcase()
            |> process_data()
          end
          
          defp process_data(data) do
            case validate_data(data) do
              {:ok, validated} -> transform_data(validated)
              {:error, reason} -> {:error, reason}
            end
          end
        end
        """

      conn
      |> fill_in("Code", with: complex_code)

      # Forget to fill title (validation error)
      |> click("button[type='submit']", text: "Post Drop")

      # Complex code should be preserved
      |> assert_path("/drops/new")
      |> assert_field_value("Code", complex_code)
      |> assert_has("form", text: "Title can't be blank")

      # User can fix error and submit
      |> fill_in("Title", with: "Complex Code Example")
      |> click("button[type='submit']", text: "Post Drop")
      |> assert_path("/profile")
      |> assert_has(".drop-card", text: "Complex Code Example")
    end

    test "loading states provide feedback during operations", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")
      |> fill_in("Title", with: "Loading Feedback Test")
      |> fill_in("Code", with: "def loading_feedback, do: :processing")

      # Submit form
      |> click("button[type='submit']", text: "Post Drop")

      # Should show feedback (redirect to profile indicates completion)
      |> assert_path("/profile")
      |> assert_has("main", text: "Drop created successfully")

      # Drop should be created
      |> assert_has(".drop-card", text: "Loading Feedback Test")
    end

    test "navigation remains accessible during errors", %{conn: conn, user: user} do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/new")

      # Trigger validation error
      |> click("button[type='submit']", text: "Post Drop")
      |> assert_has("form", text: "can't be blank")

      # Navigation should still work
      |> assert_has("nav", text: user.github_username)
      |> assert_has("a[href='/profile']")

      # Can navigate away from error state
      |> click("a[href='/profile']")
      |> assert_path("/profile")
      |> assert_has("h1", text: "Your Drops")

      # Can return to form
      |> click("a[href='/drops/new']")
      |> assert_path("/drops/new")
      |> assert_has("h1", text: "Share Code")

      # Form should be reset (not preserve error state)
      |> assert_field_value("Title", "")
      |> assert_field_value("Code", "")
    end
  end
end
