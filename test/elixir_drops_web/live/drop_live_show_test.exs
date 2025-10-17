defmodule ElixirDropsWeb.DropLiveShowTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Comments

  defp create_drop_setup(%{conn: conn}) do
    user = user_fixture()
    drop = drop_fixture(%ElixirDrops.Drops.Drop{}, user)
    conn = sign_in_user(conn, user)

    %{conn: conn, drop: drop, user: user}
  end

  describe "/d/short_id" do
    setup [:create_drop_setup]

    test "complete commenting workflow", %{conn: conn, drop: drop, user: user} do
      # Visit the drop page
      {:ok, view, html} = live(conn, ~p"/d/#{drop.short_id}")

      # Verify initial state
      assert html =~ "Comments (0)"

      # Create a comment through the form
      view
      |> form("#comment-form",
        comment: %{body: "This is my test comment **with bold**"}
      )
      |> render_submit()

      # Verify comment appears in the database
      comments = Comments.list_drop_comments(drop.id)
      assert length(comments) == 1

      comment = List.first(comments)
      assert comment.body == "This is my test comment **with bold**"
      assert comment.user_id == user.id

      # Verify comment count is updated
      updated_html = render(view)
      assert updated_html =~ "Comments (1)"
      assert updated_html =~ "This is my test comment"
      assert updated_html =~ user.name
    end

    test "comments display for non-logged-in users" do
      # Create user, drop and comment
      user = user_fixture()
      drop = drop_fixture(%ElixirDrops.Drops.Drop{}, user)

      {:ok, _comment} =
        Comments.create_comment(
          drop,
          user,
          nil,
          %{body: "Public comment"}
        )

      # Visit page without being logged in
      conn = build_conn()
      {:ok, _view, html} = live(conn, ~p"/d/#{drop.short_id}")

      # Should see the comment but not the form
      assert html =~ "Comments (1)"
      assert html =~ user.name
      assert html =~ "Sign in with GitHub"
    end

    test "user can edit a comment and see Edited flag", %{conn: conn, drop: drop, user: user} do
      {:ok, comment} =
        Comments.create_comment(drop, user, nil, %{body: "Initial body"})

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      # Submit an edit
      view
      |> form("#edit-comment-form-#{comment.id}",
        comment: %{body: "Updated body"},
        comment_id: comment.id
      )
      |> render_submit()

      # Persisted and rendered
      updated = Comments.get_comment!(comment.id)
      assert updated.body == "Updated body"

      page = render(view)
      assert page =~ "Updated body"
      assert page =~ "Edited"
    end

    test "empty comment edit causes submit button to be disabled", %{
      conn: conn,
      drop: drop,
      user: user
    } do
      {:ok, comment} =
        Comments.create_comment(drop, user, nil, %{body: "Some content"})

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      view
      |> form("#edit-comment-form-#{comment.id}",
        comment: %{body: ""},
        comment_id: comment.id,
        form_id: "edit-comment-form-#{comment.id}"
      )
      |> render_change()

      assert has_element?(view, "button#submit-button-edit-comment-form-#{comment.id}[disabled]")
    end
  end

  describe "replies on drop show" do
    setup [:create_drop_setup]

    test "user can reply to a comment and replies count appears", %{
      conn: conn,
      drop: drop,
      user: user
    } do
      {:ok, comment} =
        Comments.create_comment(drop, user, nil, %{body: "Top level"})

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      view
      |> form("#reply-form-#{comment.id}-depth-0",
        comment: %{body: "A reply"},
        parent_id: comment.id,
        form_id: "reply-form-#{comment.id}-depth-0"
      )
      |> render_submit()

      html = render(view)
      assert html =~ "A reply"
    end
  end

  describe "delete comment from modal" do
    test "soft-deletes comment and hides its body", %{conn: conn} do
      user = user_fixture()
      drop = drop_fixture(%ElixirDrops.Drops.Drop{}, user)

      {:ok, comment} =
        Comments.create_comment(drop, user, nil, %{body: "Delete me"})

      conn = sign_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}?delete_comment_id=#{comment.id}")

      # Confirm deletion in modal
      view
      |> element("#confirm-comment-deletion-#{comment.id}", "Confirm")
      |> render_click()

      # Verify soft delete and UI state
      deleted = Comments.get_comment!(comment.id)
      assert deleted.deleted_at

      page = render(view)
      refute page =~ "Delete me"
      assert page =~ "Deleted"
    end
  end

  describe "pagination and new comments indicator" do
    test "loads more comments when clicking See more responses", %{conn: conn} do
      user = user_fixture()
      drop = drop_fixture(%ElixirDrops.Drops.Drop{}, user)

      # Create 15 top-level comments with identifiable bodies
      for i <- 1..15 do
        {:ok, _} = Comments.create_comment(drop, user, nil, %{body: "Comment #{i}"})
      end

      {:ok, view, html} = live(conn, ~p"/d/#{drop.short_id}")

      # By default only 10 load; earliest ones likely absent
      # oldest (since ordered desc)
      refute html =~ "Comment 15"

      # Click load more
      view
      |> element("button", "See more responses")
      |> render_click()

      html2 = render(view)
      assert html2 =~ "Comment 15"
    end

    test "indicator appears for others' comments and streams them on click", %{conn: conn} do
      user = user_fixture()
      other = user_fixture(%{github_id: 9_999_998})
      drop = drop_fixture(%ElixirDrops.Drops.Drop{}, user)

      conn = sign_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      # Create a comment from another user to trigger indicator
      {:ok, _c} = Comments.create_comment(drop, other, nil, %{body: "From someone else"})

      Process.sleep(100)
      assert has_element?(view, "#new-comments-indicator")

      view
      |> element("#new-comments-indicator")
      |> render_click()

      page = render(view)
      refute page =~ "id=\"new-comments-indicator\""
      assert page =~ "From someone else"
    end

    test "no indicator for own new comment due to recent_comment_id", %{conn: conn} do
      user = user_fixture()
      drop = drop_fixture(%ElixirDrops.Drops.Drop{}, user)

      conn = sign_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      # Submit a new comment as the same user
      view
      |> form("#comment-form", comment: %{body: "My own"})
      |> render_submit()

      Process.sleep(100)
      refute has_element?(view, "#new-comments-indicator")
    end
  end

  describe "cancel new comment" do
    test "clears textarea content", %{conn: conn} do
      user = user_fixture()
      drop = drop_fixture(%ElixirDrops.Drops.Drop{}, user)

      conn = sign_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      unique = "Some unique draft text #{System.unique_integer()}"

      # Type into the textarea to mark field as used

      view
      |> form("#comment-form",
        comment: %{body: unique},
        comment_id: "nil",
        form_id: "comment-form"
      )
      |> render_change()

      # Click Cancel
      view
      |> element("#comment-form button", "Cancel")
      |> render_click()

      # The draft text should no longer appear in the form HTML
      refute render(view) =~ unique
    end
  end
end
