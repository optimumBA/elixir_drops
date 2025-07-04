defmodule ElixirDropsWeb.CommentsPubSubTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Comments

  setup do
    user1 = user_fixture()
    user2 = user_fixture()
    drop = drop_fixture(%ElixirDrops.Drops.Drop{}, user1)

    conn1 = sign_in_user(build_conn(), user1)
    conn2 = sign_in_user(build_conn(), user2)

    %{
      conn1: conn1,
      conn2: conn2,
      user1: user1,
      user2: user2,
      drop: drop
    }
  end

  describe "real-time comment updates" do
    test "broadcasts new comments to all connected users", %{
      conn1: conn1,
      conn2: conn2,
      user2: user2,
      drop: drop
    } do
      # Both users connect to the same drop
      {:ok, view1, _html} = live(conn1, ~p"/d/#{drop.short_id}")
      {:ok, view2, _html} = live(conn2, ~p"/d/#{drop.short_id}")

      # User 2 posts a comment
      view2
      |> form("form[phx-submit='new_comment']", comment: %{body: "Hello from user 2!"})
      |> render_submit()

      # Both views should see the new comment
      html1 = render(view1)
      html2 = render(view2)

      assert html1 =~ "Hello from user 2!"
      assert html1 =~ user2.name
      assert html2 =~ "Hello from user 2!"
      assert html2 =~ user2.name

      # Comment count should update for both
      assert html1 =~ "Comments (1)"
      assert html2 =~ "Comments (1)"
    end

    test "broadcasts comment edits to all connected users", %{
      conn1: conn1,
      conn2: conn2,
      user1: user1,
      drop: drop
    } do
      # Create a comment
      {:ok, comment} =
        Comments.create_comment(%{
          body: "Original text",
          drop_id: drop.id,
          user_id: user1.id
        })

      # Both users connect
      {:ok, view1, _html} = live(conn1, ~p"/d/#{drop.short_id}")
      {:ok, view2, _html} = live(conn2, ~p"/d/#{drop.short_id}")

      # User 1 edits their comment
      view1
      |> element("button[phx-click='edit_comment_toggle'][phx-value-comment-id='#{comment.id}']")
      |> render_click()

      view1
      |> form("form[phx-submit='update_comment'][phx-value-comment-id='#{comment.id}']",
        comment: %{body: "Edited text"}
      )
      |> render_submit()

      # Both views should see the edit
      html1 = render(view1)
      html2 = render(view2)

      assert html1 =~ "Edited text"
      assert html1 =~ "edited"
      refute html1 =~ "Original text"

      assert html2 =~ "Edited text"
      assert html2 =~ "edited"
      refute html2 =~ "Original text"
    end

    test "broadcasts comment deletions to all connected users", %{
      conn1: conn1,
      conn2: conn2,
      user1: user1,
      drop: drop
    } do
      # Create a comment
      {:ok, comment} =
        Comments.create_comment(%{
          body: "Comment to delete",
          drop_id: drop.id,
          user_id: user1.id
        })

      # Both users connect
      {:ok, view1, _html} = live(conn1, ~p"/d/#{drop.short_id}")
      {:ok, view2, _html} = live(conn2, ~p"/d/#{drop.short_id}")

      # Initial state
      assert render(view1) =~ "Comment to delete"
      assert render(view2) =~ "Comment to delete"

      # User 1 deletes their comment
      view1
      |> element("button[phx-click='delete_comment'][phx-value-comment-id='#{comment.id}']")
      |> render_click()

      # Both views should see the deletion
      html1 = render(view1)
      html2 = render(view2)

      assert html1 =~ "[deleted]"
      refute html1 =~ "Comment to delete"

      assert html2 =~ "[deleted]"
      refute html2 =~ "Comment to delete"
    end

    test "broadcasts replies to all connected users", %{
      conn1: conn1,
      conn2: conn2,
      user1: user1,
      user2: user2,
      drop: drop
    } do
      # User 1 creates a parent comment
      {:ok, parent} =
        Comments.create_comment(%{
          body: "Parent comment",
          drop_id: drop.id,
          user_id: user1.id
        })

      # Both users connect
      {:ok, view1, _html} = live(conn1, ~p"/d/#{drop.short_id}")
      {:ok, view2, _html} = live(conn2, ~p"/d/#{drop.short_id}")

      # User 2 replies to the comment
      view2
      |> element("button[phx-click='reply'][phx-value-comment-id='#{parent.id}']")
      |> render_click()

      view2
      |> form("form[phx-submit='reply_to_comment'][phx-value-comment-id='#{parent.id}']",
        comment: %{body: "Reply from user 2"}
      )
      |> render_submit()

      # Both views should see the reply
      html1 = render(view1)
      html2 = render(view2)

      assert html1 =~ "Reply from user 2"
      assert html1 =~ user2.name

      assert html2 =~ "Reply from user 2"
      assert html2 =~ user2.name
    end

    test "updates comment count in real-time for all users", %{
      conn1: conn1,
      conn2: conn2,
      drop: drop
    } do
      # Both users connect
      {:ok, view1, html1} = live(conn1, ~p"/d/#{drop.short_id}")
      {:ok, view2, html2} = live(conn2, ~p"/d/#{drop.short_id}")

      # Initially no comments
      assert html1 =~ "Comments (0)"
      assert html2 =~ "Comments (0)"

      # User 1 posts a comment
      view1
      |> form("form[phx-submit='new_comment']", comment: %{body: "First comment"})
      |> render_submit()

      # Both should see count update
      assert render(view1) =~ "Comments (1)"
      assert render(view2) =~ "Comments (1)"

      # User 2 posts a comment
      view2
      |> form("form[phx-submit='new_comment']", comment: %{body: "Second comment"})
      |> render_submit()

      # Both should see count update again
      assert render(view1) =~ "Comments (2)"
      assert render(view2) =~ "Comments (2)"
    end
  end
end
