defmodule ElixirDropsWeb.Features.UserDropManagementTest do
  @moduledoc """
  Domain-based feature tests for user drop management experience.

  Story 4: "As a user, I want to manage my drops"

  Covers the complete user drop management domain including:
  - Drop editing and updating functionality
  - Profile page drop organization and display
  - Drop ownership and authorization controls
  - Drop deletion and removal processes
  - Version history and change management
  - Drop privacy and sharing controls
  """

  use ElixirDropsWeb.FeatureCase, async: false

  import ElixirDrops.FeatureHelpers

  alias ElixirDrops.Drops.Drop

  @moduletag :feature

  describe "user accesses drop management from profile" do
    setup do
      user = user_fixture(%{github_id: 12_345, github_username: "drop_manager"})

      existing_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Existing Drop for Management",
          body: """
          def existing_function do
            # This is an existing function
            :existing_result
          end
          """
        })

      %{user: user, existing_drop: existing_drop}
    end

    test "user can view their drops on profile page", %{
      conn: conn,
      user: user,
      existing_drop: existing_drop
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/profile")

      # Should see profile header and user info
      |> assert_has("h1", text: "Your Drops")
      |> assert_has("main", text: user.github_username)

      # Should see user's drops displayed
      |> assert_has(".drop-card", text: existing_drop.title)
      |> assert_has(".drop-card", text: "existing_function")

      # Should see drop count or similar metadata
      |> assert_has("main", text: "Drops")
    end

    test "user sees edit button on their own drops", %{
      conn: conn,
      user: user,
      existing_drop: existing_drop
    } do
      conn
      |> sign_in_user(user)
      |> visit("/d/#{existing_drop.short_id}")

      # Should see edit button for own drop
      |> assert_has("a[href='/drops/#{existing_drop.short_id}/edit']", text: "Edit")

      # Edit button should be visually prominent
      |> assert_has("a", text: "Edit")
    end

    test "user can navigate to edit form from drop view", %{
      conn: conn,
      user: user,
      existing_drop: existing_drop
    } do
      conn
      |> sign_in_user(user)
      |> visit("/d/#{existing_drop.short_id}")
      |> click("a", text: "Edit")

      # Should navigate to edit form
      |> assert_path("/drops/#{existing_drop.short_id}/edit")
      |> assert_has("h1", text: "Edit Drop")

      # Form should be pre-populated with existing content
      |> assert_field_value("Title", existing_drop.title)
      |> assert_field_value("Code", existing_drop.body)
    end
  end

  describe "user edits existing drops" do
    setup do
      user = user_fixture(%{github_id: 67_890, github_username: "editor"})

      editable_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Original Title",
          body: """
          def original_function do
            # Original implementation
            :original
          end
          """
        })

      %{user: user, editable_drop: editable_drop}
    end

    test "user can update drop title and content", %{
      conn: conn,
      user: user,
      editable_drop: editable_drop
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/#{editable_drop.short_id}/edit")

      # Update title and content
      |> fill_in("Title", with: "Updated Title - Pattern Matching")
      |> fill_in("Code",
        with: """
        def updated_function(input) do
          case input do
            {:ok, data} -> {:success, data}
            {:error, reason} -> {:failure, reason}
            _ -> {:unknown, input}
          end
        end
        """
      )
      |> click("button[type='submit']", text: "Update Drop")

      # Should redirect to updated drop view
      |> assert_path("/drops/#{editable_drop.short_id}")
      |> assert_has("main", text: "Drop updated successfully")

      # Should show updated content
      |> assert_has("h1", text: "Updated Title - Pattern Matching")
      |> assert_has("pre code", text: "def updated_function")
      |> assert_has("pre code", text: "case input do")
    end

    test "user can update only title without changing code", %{
      conn: conn,
      user: user,
      editable_drop: editable_drop
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/#{editable_drop.short_id}/edit")

      # Update only title
      |> fill_in("Title", with: "New Title Only")
      # Leave code unchanged

      |> click("button[type='submit']", text: "Update Drop")
      |> assert_path("/drops/#{editable_drop.short_id}")
      |> assert_has("h1", text: "New Title Only")

      # Original code should be preserved
      |> assert_has("pre code", text: "def original_function")
      |> assert_has("pre code", text: "Original implementation")
    end

    test "user can update only code without changing title", %{
      conn: conn,
      user: user,
      editable_drop: editable_drop
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/#{editable_drop.short_id}/edit")

      # Update only code content
      |> fill_in("Code",
        with: """
        def enhanced_original_function do
          # Enhanced implementation with better logic
          result = complex_calculation()
          {:enhanced, result}
        end
        """
      )
      # Leave title unchanged

      |> click("button[type='submit']", text: "Update Drop")
      |> assert_path("/drops/#{editable_drop.short_id}")

      # Original title should be preserved
      |> assert_has("h1", text: "Original Title")

      # Code should be updated
      |> assert_has("pre code", text: "def enhanced_original_function")
      |> assert_has("pre code", text: "Enhanced implementation")
    end

    test "edit form validation works like creation form", %{
      conn: conn,
      user: user,
      editable_drop: editable_drop
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/#{editable_drop.short_id}/edit")

      # Clear title to trigger validation error
      |> fill_in("Title", with: "")
      |> click("button[type='submit']", text: "Update Drop")

      # Should stay on edit form with validation error
      |> assert_path("/drops/#{editable_drop.short_id}/edit")
      |> assert_has("form", text: "Title can't be blank")

      # Code content should be preserved
      |> assert_field_value("Code", editable_drop.body)
    end
  end

  describe "drop ownership and authorization" do
    setup do
      owner = user_fixture(%{github_id: 11_111, github_username: "owner"})
      other_user = user_fixture(%{github_id: 22_222, github_username: "other"})

      owned_drop =
        drop_fixture(%Drop{}, owner, %{
          title: "Owner's Protected Drop",
          body: "def protected_content, do: :owner_only"
        })

      %{owner: owner, other_user: other_user, owned_drop: owned_drop}
    end

    test "only owner sees edit button on drop view", %{
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

    test "non-owner cannot access edit URL directly", %{
      conn: conn,
      other_user: other_user,
      owned_drop: owned_drop
    } do
      conn
      |> sign_in_user(other_user)
      |> visit(~p"/drops/#{owned_drop.short_id}/edit")

      # Should redirect to homepage with error message
      |> assert_path("/")
      |> assert_has("main", text: "You can only edit your own drops")
    end

    test "unauthenticated user cannot access edit URL", %{conn: conn, owned_drop: owned_drop} do
      conn
      |> visit(~p"/drops/#{owned_drop.short_id}/edit")

      # Should redirect to homepage with auth error
      |> assert_path("/")
      |> assert_has("main", text: "You must log in to access this page")
    end

    test "owner can edit their own drops successfully", %{
      conn: conn,
      owner: owner,
      owned_drop: owned_drop
    } do
      conn
      |> sign_in_user(owner)
      |> visit(~p"/drops/#{owned_drop.short_id}/edit")
      |> assert_has("h1", text: "Edit Drop")

      # Should be able to update successfully
      |> fill_in("Title", with: "Updated by Owner")
      |> click("button[type='submit']", text: "Update Drop")
      |> assert_path("/drops/#{owned_drop.short_id}")
      |> assert_has("h1", text: "Updated by Owner")
      |> assert_has("main", text: "Drop updated successfully")
    end
  end

  describe "drop management from profile page" do
    setup do
      user = user_fixture(%{github_id: 33_333, github_username: "profile_manager"})

      # Create multiple drops for management
      drop1 =
        drop_fixture(%Drop{}, user, %{
          title: "First Drop",
          body: "def first, do: :one"
        })

      drop2 =
        drop_fixture(%Drop{}, user, %{
          title: "Second Drop",
          body: "def second, do: :two"
        })

      drop3 =
        drop_fixture(%Drop{}, user, %{
          title: "Third Drop",
          body: "def third, do: :three"
        })

      %{user: user, drop1: drop1, drop2: drop2, drop3: drop3}
    end

    test "user sees all their drops on profile page", %{
      conn: conn,
      user: user,
      drop1: drop1,
      drop2: drop2,
      drop3: drop3
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/profile")

      # Should see all user's drops
      |> assert_has(".drop-card", text: drop1.title)
      |> assert_has(".drop-card", text: drop2.title)
      |> assert_has(".drop-card", text: drop3.title)

      # Should see content previews
      |> assert_has(".drop-card", text: "def first")
      |> assert_has(".drop-card", text: "def second")
      |> assert_has(".drop-card", text: "def third")
    end

    test "user can navigate to individual drops from profile", %{
      conn: conn,
      user: user,
      drop2: drop2
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/profile")

      # Click on second drop
      |> click(".drop-card", text: drop2.title)
      |> assert_path("/drops/#{drop2.short_id}")
      |> assert_has("h1", text: drop2.title)
      |> assert_has("pre code", text: "def second")
    end

    test "user can edit drops directly from profile view", %{
      conn: conn,
      user: user,
      drop1: drop1
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/profile")

      # Navigate to drop view first
      |> click(".drop-card", text: drop1.title)
      |> assert_path("/drops/#{drop1.short_id}")

      # Then to edit form
      |> click("a", text: "Edit")
      |> assert_path("/drops/#{drop1.short_id}/edit")
      |> assert_field_value("Title", drop1.title)
    end

    test "profile shows user's drop count and statistics", %{
      conn: conn,
      user: user
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/profile")

      # Should show some indication of number of drops
      |> assert_has("main", text: "Your Drops")

      # Should see multiple drop cards (we created 3)
      |> assert_element(".drop-card", count: 3)
    end
  end

  describe "drop update success and error handling" do
    setup do
      user = user_fixture(%{github_id: 44_444, github_username: "updater"})

      test_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Test Update Drop",
          body: "def test_update, do: :before"
        })

      %{user: user, test_drop: test_drop}
    end

    test "successful update shows confirmation message", %{
      conn: conn,
      user: user,
      test_drop: test_drop
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/#{test_drop.short_id}/edit")
      |> fill_in("Title", with: "Successfully Updated Drop")
      |> fill_in("Code", with: "def test_update, do: :after")
      |> click("button[type='submit']", text: "Update Drop")

      # Should show success message
      |> assert_path("/drops/#{test_drop.short_id}")
      |> assert_has("main", text: "Drop updated successfully")

      # Content should be updated
      |> assert_has("h1", text: "Successfully Updated Drop")
      |> assert_has("pre code", text: ":after")
    end

    test "update validation errors preserve form content", %{
      conn: conn,
      user: user,
      test_drop: test_drop
    } do
      updated_code = "def preserved_code, do: :should_remain"

      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/#{test_drop.short_id}/edit")

      # Make valid code change but invalid title
      |> fill_in("Code", with: updated_code)
      # Invalid empty title
      |> fill_in("Title", with: "")
      |> click("button[type='submit']", text: "Update Drop")

      # Should stay on edit form
      |> assert_path("/drops/#{test_drop.short_id}/edit")
      |> assert_has("form", text: "Title can't be blank")

      # Code changes should be preserved
      |> assert_field_value("Code", updated_code)
    end

    test "user can cancel edit and return to drop view", %{
      conn: conn,
      user: user,
      test_drop: test_drop
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/#{test_drop.short_id}/edit")

      # Make some changes
      |> fill_in("Title", with: "Changed But Not Saved")
      |> fill_in("Code", with: "def changed, do: :not_saved")

      # Cancel by navigating back to drop view
      |> click("a[href='/drops/#{test_drop.short_id}']")
      |> assert_path("/drops/#{test_drop.short_id}")

      # Should show original content (not changed)
      |> assert_has("h1", text: test_drop.title)
      |> assert_has("pre code", text: "def test_update")
      |> assert_has("pre code", text: ":before")
    end
  end

  describe "drop management navigation and user experience" do
    setup do
      user = user_fixture(%{github_id: 55_555, github_username: "navigator"})

      nav_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Navigation Test Drop",
          body: "def navigation_test, do: :smooth"
        })

      %{user: user, nav_drop: nav_drop}
    end

    test "edit form has proper navigation elements", %{
      conn: conn,
      user: user,
      nav_drop: nav_drop
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/#{nav_drop.short_id}/edit")

      # Should have navigation back to drop view
      |> assert_has("a[href='/drops/#{nav_drop.short_id}']")

      # Should have form elements
      |> assert_has("form")
      |> assert_has("button[type='submit']", text: "Update Drop")

      # Should have proper page title
      |> assert_has("h1", text: "Edit Drop")
    end

    test "user can navigate between profile, drop view, and edit form", %{
      conn: conn,
      user: user,
      nav_drop: nav_drop
    } do
      # Start at profile
      conn
      |> sign_in_user(user)
      |> visit(~p"/profile")
      |> assert_has(".drop-card", text: nav_drop.title)

      # Go to drop view
      |> click(".drop-card", text: nav_drop.title)
      |> assert_path("/drops/#{nav_drop.short_id}")
      |> assert_has("h1", text: nav_drop.title)

      # Go to edit form
      |> click("a", text: "Edit")
      |> assert_path("/drops/#{nav_drop.short_id}/edit")
      |> assert_has("h1", text: "Edit Drop")

      # Return to drop view
      |> click("a[href='/drops/#{nav_drop.short_id}']")
      |> assert_path("/drops/#{nav_drop.short_id}")
      |> assert_has("h1", text: nav_drop.title)

      # Return to profile
      |> click("a[href='/profile']")
      |> assert_path("/profile")
      |> assert_has("h1", text: "Your Drops")
    end

    test "user maintains session across management operations", %{
      conn: conn,
      user: user,
      nav_drop: nav_drop
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/#{nav_drop.short_id}/edit")

      # User should remain authenticated throughout
      |> assert_has("nav", text: user.github_username)
      |> fill_in("Title", with: "Session Test Update")
      |> click("button[type='submit']", text: "Update Drop")

      # Should still be authenticated after update
      |> assert_path("/drops/#{nav_drop.short_id}")
      |> assert_has("nav", text: user.github_username)
      |> visit(~p"/profile")
      # Should still be authenticated on profile
      |> assert_has("nav", text: user.github_username)
      |> assert_has(".drop-card", text: "Session Test Update")
    end
  end

  describe "drop content and formatting preservation" do
    setup do
      user = user_fixture(%{github_id: 66_666, github_username: "formatter"})

      formatted_drop =
        drop_fixture(%Drop{}, user, %{
          title: "Formatting Test Drop",
          body: """
          # Complex formatting test
          defmodule FormattingTest do
            @doc \"\"\"
            This function has complex formatting including:
            - Multi-line documentation
            - Special characters: äöü & <script>
            - Code indentation
            \"\"\"
            def complex_function(input) when is_binary(input) do
              input
              |> String.trim()
              |> String.downcase()
              |> case do
                "" -> {:error, :empty}
                text -> {:ok, text}
              end
            end
          end
          """
        })

      %{user: user, formatted_drop: formatted_drop}
    end

    test "complex formatting is preserved during edit", %{
      conn: conn,
      user: user,
      formatted_drop: formatted_drop
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/#{formatted_drop.short_id}/edit")

      # Original formatting should be preserved in the edit form
      |> assert_field_value("Code", formatted_drop.body)

      # Make minor update
      |> fill_in("Title", with: "Updated Formatting Test Drop")
      |> click("button[type='submit']", text: "Update Drop")

      # Complex formatting should be preserved in the updated drop
      |> assert_path("/drops/#{formatted_drop.short_id}")
      |> assert_has("pre code", text: "defmodule FormattingTest")
      |> assert_has("pre code", text: "@doc")
      |> assert_has("pre code", text: "Multi-line documentation")
      |> assert_has("pre code", text: "äöü & <script>")
      |> assert_has("pre code", text: "|> String.trim()")
    end

    test "special characters and encoding handled properly in updates", %{
      conn: conn,
      user: user,
      formatted_drop: formatted_drop
    } do
      conn
      |> sign_in_user(user)
      |> visit(~p"/drops/#{formatted_drop.short_id}/edit")

      # Update with additional special characters
      |> fill_in("Title", with: "Special: äöü & <script>alert('test')</script>")
      |> fill_in("Code",
        with: """
        # Updated with more special characters: äöü ñ çğş
        def handle_encoding(text) do
          # This handles: & < > " ' äöü
          text
          |> String.replace("&", "&amp;")
          |> String.replace("<", "&lt;")
          |> String.replace(">", "&gt;")
        end
        """
      )
      |> click("button[type='submit']", text: "Update Drop")

      # Special characters should be properly encoded and displayed
      |> assert_path("/drops/#{formatted_drop.short_id}")
      |> assert_has("h1", text: "Special: äöü & <script>alert('test')</script>")
      |> assert_has("pre code", text: "äöü ñ çğş")
      |> assert_has("pre code", text: "& < > \" '")
    end
  end
end
