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

    test "valid body adds a comment", %{conn: conn, drop: drop, user: user} do
      {:ok, view, html} = live(conn, ~p"/d/#{drop.short_id}")

      assert html =~ "Comments (0)"

      view
      |> form("#comment-form",
        comment: %{body: "This is my test comment"}
      )
      |> render_submit()

      updated_html = render(view)
      assert updated_html =~ "Comments (1)"
      assert updated_html =~ "This is my test comment"
      assert updated_html =~ user.name
    end

    test "invalid body adds an error message to the page", %{conn: conn, drop: drop} do
      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      view
      |> form("#comment-form",
        comment: %{body: ""}
      )
      |> render_submit()

      updated_html = render(view)
      assert updated_html =~ "Failed to add your comment"
      assert updated_html =~ "Comments (0)"
    end

    test "comments display for non-logged-in users" do
      user = user_fixture()
      drop = drop_fixture(%ElixirDrops.Drops.Drop{}, user)

      {:ok, _comment} =
        Comments.create_comment(
          drop,
          user,
          nil,
          %{body: "Public comment"}
        )

      conn = build_conn()
      {:ok, _view, html} = live(conn, ~p"/d/#{drop.short_id}")

      assert html =~ "Comments (1)"
      assert html =~ user.name
      assert html =~ "Sign in with GitHub"
    end

    test "user can edit a comment and see edited flag", %{conn: conn, drop: drop, user: user} do
      {:ok, comment} =
        Comments.create_comment(drop, user, nil, %{body: "Initial body"})

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      view
      |> form("#edit-comment-form-#{comment.id}",
        comment: %{body: "Updated body"},
        comment_id: comment.id
      )
      |> render_submit()

      html = render(view)
      assert html =~ "Updated body"
      assert html =~ "Edited"
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

    test "character count changes as the user types more text", %{
      conn: conn,
      drop: drop,
      user: user
    } do
      {:ok, comment} =
        Comments.create_comment(drop, user, nil, %{body: "Some content"})

      {:ok, reply_comment} =
        Comments.create_comment(drop, user, comment, %{body: "Some reply to a comment"})

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      form_id = "reply-form-#{reply_comment.id}-depth-1"

      view
      |> form("##{form_id}",
        comment: %{body: "24"},
        form_id: "#{form_id}"
      )
      |> render_change()

      assert_push_event(view, "reply_char_count", %{
        count: 2,
        form_id: _form_id
      })
    end

    test "clicking the edit comment button pre-fills the UI with the comment body character count",
         %{
           conn: conn,
           drop: drop,
           user: user
         } do
      {:ok, comment} =
        Comments.create_comment(drop, user, nil, %{body: "content"})

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      view
      |> element("#trigger-comment-edit-#{comment.id}", "Edit comment")
      |> render_click()

      assert_push_event(view, "reply_char_count", %{
        count: 7,
        form_id: _form_id
      })
    end

    test "user can reply to a comment", %{
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

      assert render(view) =~ "A reply"
    end

    test "soft-deletes comment and hides its body", %{
      conn: conn,
      drop: drop,
      user: user
    } do
      {:ok, comment} =
        Comments.create_comment(drop, user, nil, %{body: "Delete me"})

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}?delete_comment_id=#{comment.id}")

      view
      |> element("#confirm-comment-deletion-#{comment.id}", "Confirm")
      |> render_click()

      deleted_comment = Comments.get_comment!(comment.id)
      assert deleted_comment.deleted_at

      html = render(view)
      refute html =~ "Delete me"
      assert html =~ "Deleted"
    end

    test "loads more comments when clicking \'see more responses\' button", %{
      conn: conn,
      drop: drop,
      user: user
    } do
      for i <- 1..15 do
        {:ok, _} = Comments.create_comment(drop, user, nil, %{body: "Comment #{i}"})
      end

      {:ok, view, html} = live(conn, ~p"/d/#{drop.short_id}")

      refute html =~ "Comment 15"

      view
      |> element("button", "See more responses")
      |> render_click()

      assert render(view) =~ "Comment 15"
    end

    test "indicator appears for others' comments and streams them on click", %{
      conn: conn,
      drop: drop
    } do
      other = user_fixture(%{github_id: 9_999_998})

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      {:ok, _c} = Comments.create_comment(drop, other, nil, %{body: "From someone else"})

      Process.sleep(100)
      assert has_element?(view, "#new-comments-indicator")

      view
      |> element("#new-comments-indicator")
      |> render_click()

      html = render(view)
      refute html =~ "id=\"new-comments-indicator\""
      assert html =~ "From someone else"
    end

    test "indicator does not appear for own new comment", %{
      conn: conn,
      drop: drop
    } do
      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      view
      |> form("#comment-form", comment: %{body: "My own"})
      |> render_submit()

      Process.sleep(100)
      refute has_element?(view, "#new-comments-indicator")
    end

    test "cancel button clears textarea content", %{
      conn: conn,
      drop: drop
    } do
      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      unique = "Some unique draft text #{System.unique_integer()}"

      view
      |> form("#comment-form",
        comment: %{body: unique},
        comment_id: "nil",
        form_id: "comment-form"
      )
      |> render_change()

      view
      |> element("#comment-form button", "Cancel")
      |> render_click()

      refute render(view) =~ unique
    end
  end
end
