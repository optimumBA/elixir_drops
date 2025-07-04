defmodule ElixirDropsWeb.CommentsLiveTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Comments

  describe "comments integration" do
    setup %{conn: conn} do
      user = user_fixture()
      drop = drop_fixture(%ElixirDrops.Drops.Drop{}, user)

      conn = sign_in_user(conn, user)

      %{conn: conn, user: user, drop: drop}
    end

    test "displays comment form when user is logged in", %{conn: conn, drop: drop} do
      {:ok, _view, html} = live(conn, ~p"/d/#{drop.short_id}")

      assert html =~ "Add a comment"
      assert html =~ "Post Comment"
      assert html =~ "Comments (0)"
    end

    test "allows user to create a comment", %{conn: conn, user: user, drop: drop} do
      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      # Submit a new comment
      view
      |> form("form[phx-submit='new_comment']", comment: %{body: "This is a test comment"})
      |> render_submit()

      # Verify comment was created in the database
      comments = Comments.list_drop_comments(drop.id)
      comment = List.first(comments)
      assert comment.body == "This is a test comment"
      assert comment.user_id == user.id
      assert comment.drop_id == drop.id
    end

    test "displays created comments", %{conn: conn, user: user, drop: drop} do
      # Create a comment first
      {:ok, _comment} =
        Comments.create_comment(%{
          body: "Test comment",
          drop_id: drop.id,
          user_id: user.id
        })

      {:ok, _view, html} = live(conn, ~p"/d/#{drop.short_id}")

      assert html =~ "Test comment"
      assert html =~ user.name
      assert html =~ "Comments (1)"
    end

    test "allows replying to comments", %{conn: conn, user: user, drop: drop} do
      # Create a parent comment
      {:ok, parent_comment} =
        Comments.create_comment(%{
          body: "Parent comment",
          drop_id: drop.id,
          user_id: user.id
        })

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      # Click reply button to show reply form
      view
      |> element("button[phx-click='reply'][phx-value-comment-id='#{parent_comment.id}']")
      |> render_click()

      # Check that reply form is shown
      html = render(view)
      assert html =~ "Write a reply..."

      # Submit a reply using the reply form that appears
      view
      |> element(
        "form[phx-submit='reply_to_comment'][phx-value-comment-id='#{parent_comment.id}']"
      )
      |> render_submit(%{comment: %{body: "Reply to comment"}})

      # Verify reply was created in database
      comments = Comments.list_drop_comments(drop.id)
      parent_with_replies = List.first(comments)
      assert parent_with_replies.id == parent_comment.id
      assert length(parent_with_replies.replies) == 1
      assert List.first(parent_with_replies.replies).body == "Reply to comment"
    end

    test "displays comment count correctly", %{conn: conn, user: user, drop: drop} do
      {:ok, _view, html} = live(conn, ~p"/d/#{drop.short_id}")
      assert html =~ "Comments (0)"

      # Create comments
      Comments.create_comment(%{body: "Comment 1", drop_id: drop.id, user_id: user.id})
      Comments.create_comment(%{body: "Comment 2", drop_id: drop.id, user_id: user.id})

      {:ok, _view, updated_html} = live(conn, ~p"/d/#{drop.short_id}")
      assert updated_html =~ "Comments (2)"
    end

    test "prevents non-logged-in users from commenting", %{drop: drop} do
      conn = build_conn()
      {:ok, _view, html} = live(conn, ~p"/d/#{drop.short_id}")

      assert html =~ "Sign in with GitHub"
      assert html =~ "to join the discussion"
      refute html =~ "Add a comment"
    end

    test "handles markdown formatting in comments", %{conn: conn, user: _user, drop: drop} do
      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      # Submit a comment with markdown
      view
      |> form("form[phx-submit='new_comment']", comment: %{body: "**Bold** and *italic* text"})
      |> render_submit()

      # Verify markdown was processed
      comments = Comments.list_drop_comments(drop.id)
      comment = List.first(comments)
      assert comment.body_html =~ "<strong>Bold</strong>"
      assert comment.body_html =~ "<em>italic</em>"
    end

    test "shows edit and delete buttons for comment owner", %{conn: conn, user: user, drop: drop} do
      # Create a comment
      {:ok, comment} =
        Comments.create_comment(%{
          body: "My comment",
          drop_id: drop.id,
          user_id: user.id
        })

      {:ok, _view, html} = live(conn, ~p"/d/#{drop.short_id}")

      assert html =~ "Edit"
      assert html =~ "Delete"
      assert html =~ "My comment"
      assert html =~ comment.id
    end

    test "does not show edit/delete buttons for other users' comments", %{drop: drop} do
      # Create comment by original user
      original_user = user_fixture(%{github_id: 111_111})

      {:ok, _comment} =
        Comments.create_comment(%{
          body: "Original user comment",
          drop_id: drop.id,
          user_id: original_user.id
        })

      # Login as different user
      different_user = user_fixture(%{github_id: 222_222})
      different_conn = sign_in_user(build_conn(), different_user)

      {:ok, _view, html} = live(different_conn, ~p"/d/#{drop.short_id}")

      assert html =~ "Original user comment"
      refute html =~ "Edit"
      refute html =~ "Delete"
    end

    test "allows loading more comments", %{conn: conn, user: user, drop: drop} do
      # Create 15 comments to test pagination
      for i <- 1..15 do
        {:ok, _} =
          Comments.create_comment(%{
            body: "Test comment number #{i}",
            drop_id: drop.id,
            user_id: user.id
          })
      end

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      # Wait for comments to load
      Process.sleep(50)
      html = render(view)

      # Should show comment count
      assert html =~ "Comments (15)"

      # Should show load more button when more than 10 comments
      assert html =~ "Load more comments"

      # Count visible comments (should be 10)
      visible_count =
        Enum.count(1..15, fn i ->
          String.contains?(html, "Test comment number #{i}")
        end)

      assert visible_count == 10

      # Click load more
      view
      |> element("button", "Load more comments")
      |> render_click()

      # Wait and re-render
      Process.sleep(50)
      updated_html = render(view)

      # Now all 15 comments should be visible
      all_visible =
        Enum.count(1..15, fn i ->
          String.contains?(updated_html, "Test comment number #{i}")
        end)

      assert all_visible == 15

      # Load more button should be hidden
      refute updated_html =~ "Load more comments"
    end

    test "allows editing own comments", %{conn: conn, user: user, drop: drop} do
      {:ok, comment} =
        Comments.create_comment(%{
          body: "Original comment text",
          drop_id: drop.id,
          user_id: user.id
        })

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      # Click edit button
      view
      |> element("button[phx-click='edit_comment_toggle'][phx-value-comment-id='#{comment.id}']")
      |> render_click()

      # Edit form should appear with current text
      edit_html = render(view)
      assert edit_html =~ "value=\"Original comment text\""
      assert edit_html =~ "Save"
      assert edit_html =~ "Cancel"

      # Submit edited comment
      view
      |> form("form[phx-submit='update_comment'][phx-value-comment-id='#{comment.id}']",
        comment: %{body: "Edited comment text"}
      )
      |> render_submit()

      # Comment should be updated
      updated_html = render(view)
      assert updated_html =~ "Edited comment text"
      assert updated_html =~ "edited"
      refute updated_html =~ "Original comment text"
    end

    test "cancels edit mode when clicking cancel", %{conn: conn, user: user, drop: drop} do
      {:ok, comment} =
        Comments.create_comment(%{
          body: "Original comment",
          drop_id: drop.id,
          user_id: user.id
        })

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      # Click edit button
      view
      |> element("button[phx-click='edit_comment_toggle'][phx-value-comment-id='#{comment.id}']")
      |> render_click()

      # Edit form should appear
      edit_html = render(view)
      assert edit_html =~ "Save"
      assert edit_html =~ "Cancel"

      # Click cancel button
      view
      |> element("button[phx-click='cancel_edit']")
      |> render_click()

      # Edit form should disappear, original comment should remain
      cancel_html = render(view)
      refute cancel_html =~ "Save"
      refute cancel_html =~ "Cancel"
      assert cancel_html =~ "Original comment"
      assert cancel_html =~ "Edit"
    end

    test "validates edit comment form", %{conn: conn, user: user, drop: drop} do
      {:ok, comment} =
        Comments.create_comment(%{
          body: "Original comment",
          drop_id: drop.id,
          user_id: user.id
        })

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      # Click edit button
      view
      |> element("button[phx-click='edit_comment_toggle'][phx-value-comment-id='#{comment.id}']")
      |> render_click()

      # Try to submit empty comment
      view
      |> form("form[phx-submit='update_comment'][phx-value-comment-id='#{comment.id}']",
        comment: %{body: ""}
      )
      |> render_submit()

      # Should show validation error
      error_html = render(view)
      assert error_html =~ "can&#39;t be blank"

      # Original comment should still be visible
      assert error_html =~ "Original comment"
    end

    test "prevents editing other users' comments", %{conn: conn, user: _user, drop: drop} do
      # Create another user and their comment
      other_user = user_fixture()

      {:ok, _comment} =
        Comments.create_comment(%{
          body: "Other user's comment",
          drop_id: drop.id,
          user_id: other_user.id
        })

      {:ok, _view, html} = live(conn, ~p"/d/#{drop.short_id}")

      # Should not see edit button for other user's comment
      assert html =~ "Other user's comment"
      refute html =~ "Edit"
    end

    test "allows deleting own comments", %{conn: conn, user: user, drop: drop} do
      {:ok, comment} =
        Comments.create_comment(%{
          body: "Comment to delete",
          drop_id: drop.id,
          user_id: user.id
        })

      {:ok, view, html} = live(conn, ~p"/d/#{drop.short_id}")
      assert html =~ "Comment to delete"

      # Click delete button
      view
      |> element("button[phx-click='delete_comment'][phx-value-comment-id='#{comment.id}']")
      |> render_click()

      # Comment should be marked as deleted
      deleted_html = render(view)
      assert deleted_html =~ "[deleted]"
      refute deleted_html =~ "Comment to delete"
    end

    test "prevents deleting other users' comments", %{conn: conn, user: _user, drop: drop} do
      # Create another user and their comment
      other_user = user_fixture()

      {:ok, _comment} =
        Comments.create_comment(%{
          body: "Other user's comment to keep",
          drop_id: drop.id,
          user_id: other_user.id
        })

      {:ok, _view, html} = live(conn, ~p"/d/#{drop.short_id}")

      # Should not see delete button for other user's comment
      assert html =~ "Other user's comment to keep"
      refute html =~ "Delete"
    end

    test "updates comment count when deleting", %{conn: conn, user: user, drop: drop} do
      # Create multiple comments
      {:ok, comment1} =
        Comments.create_comment(%{body: "First", drop_id: drop.id, user_id: user.id})

      {:ok, _comment2} =
        Comments.create_comment(%{body: "Second", drop_id: drop.id, user_id: user.id})

      {:ok, view, html} = live(conn, ~p"/d/#{drop.short_id}")
      assert html =~ "Comments (2)"

      # Delete first comment
      view
      |> element("button[phx-click='delete_comment'][phx-value-comment-id='#{comment1.id}']")
      |> render_click()

      # Comment count should decrease
      count_html = render(view)
      assert count_html =~ "Comments (1)"
    end

    test "deleting parent comment preserves replies", %{conn: conn, user: user, drop: drop} do
      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      # Create parent comment
      {:ok, parent} =
        Comments.create_comment(%{
          body: "Parent comment",
          drop_id: drop.id,
          user_id: user.id
        })

      # Create reply
      {:ok, _reply} =
        Comments.create_comment(%{
          body: "Reply to parent",
          drop_id: drop.id,
          user_id: user.id,
          parent_id: parent.id
        })

      # Re-render to get the updated view state
      html = render(view)
      assert html =~ "Parent comment"
      assert html =~ "Reply to parent"

      # Delete parent comment
      view
      |> element("button[phx-click='delete_comment'][phx-value-comment-id='#{parent.id}']")
      |> render_click()

      # Parent should show as deleted, reply should still exist
      final_html = render(view)
      assert final_html =~ "[deleted]"
      assert final_html =~ "Reply to parent"
    end

    test "clears comment form after successful submission", %{conn: conn, drop: drop} do
      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      # Type in the comment form
      view
      |> form("form[phx-submit='new_comment']", comment: %{body: "My test comment"})
      |> render_change()

      # Submit the form
      view
      |> form("form[phx-submit='new_comment']", comment: %{body: "My test comment"})
      |> render_submit()

      # Comment should be created
      html = render(view)
      assert html =~ "My test comment"

      # Form should be cleared - check the textarea value
      assert html =~ ~r/<textarea[^>]*>[\s]*<\/textarea>/
    end

    test "validates comment form on submit", %{conn: conn, drop: drop} do
      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      # Submit empty form
      view
      |> form("form[phx-submit='new_comment']", comment: %{body: ""})
      |> render_submit()

      # Should show validation error
      html = render(view)
      assert html =~ "can&#39;t be blank"
    end

    test "preserves form content when toggling reply mode", %{conn: conn, user: user, drop: drop} do
      # Create a comment to reply to
      {:ok, comment} =
        Comments.create_comment(%{
          body: "Parent comment",
          drop_id: drop.id,
          user_id: user.id
        })

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      # Type in the main comment form
      view
      |> form("form[phx-submit='new_comment']", comment: %{body: "My draft comment"})
      |> render_change()

      # Click reply button
      view
      |> element("button[phx-click='reply'][phx-value-comment-id='#{comment.id}']")
      |> render_click()

      # Main form content should be preserved
      html = render(view)
      assert html =~ "My draft comment"

      # Reply form should be visible
      assert html =~ "Reply to"
    end
  end
end
