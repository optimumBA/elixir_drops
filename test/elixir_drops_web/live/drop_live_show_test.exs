defmodule ElixirDropsWeb.DropLiveShowTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.BookmarksFixtures
  import ElixirDrops.CommentsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Comments
  alias ElixirDrops.Drops.Drop

  defp create_drop_setup(%{conn: conn}) do
    user = user_fixture()
    drop = drop_fixture(%Drop{}, user)
    conn = sign_in_user(conn, user)

    %{conn: conn, drop: drop, user: user}
  end

  describe "/d/short_id" do
    setup [:create_drop_setup]

    test "a user who has logged in can bookmark a drop", %{conn: conn, drop: drop} do
      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      assert view
             |> element("#bookmark-button-#{drop.id}", "Bookmark Drop")
             |> render_click() =~ "Remove Bookmark"
    end

    test "a user who has logged in can unbookmark a drop", %{conn: conn, drop: drop, user: user} do
      _bookmark = bookmark_fixture(%{drop_id: drop.id, user_id: user.id})

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      assert view
             |> element("#remove-bookmark-button-#{drop.id}", "Remove Bookmark")
             |> render_click() =~ "Bookmark Drop"
    end

    test "a user who has not logged in can neither bookmark nor unbookmark a drop", %{drop: drop} do
      conn = build_conn()
      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      refute view
             |> element("#bookmark-button-#{drop.id}", "Bookmark Drop")
             |> has_element?()

      refute view
             |> element("#remove-bookmark-button-#{drop.id}", "Remove Bookmark")
             |> has_element?()
    end

    test "a user who has logged in can add comments", %{conn: conn, drop: drop, user: user} do
      {:ok, view, html} = live(conn, ~p"/d/#{drop.short_id}")

      assert html =~ "Comments (0)"

      assert has_element?(view, "button#submit-button-new-comment-form[disabled]")

      view
      |> form("#new-comment-form",
        comment: %{body: "This is my test comment"}
      )
      |> render_submit()

      updated_html = render(view)
      assert updated_html =~ "Comments (1)"
      assert updated_html =~ "This is my test comment"
      assert updated_html =~ user.name
    end

    test "a user who has not logged in cannot add comments", %{drop: drop} do
      conn = build_conn()
      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      refute view
             |> element("#new-comment-form")
             |> has_element?()
    end

    test "comments display for non-logged-in users" do
      user = user_fixture()
      drop = drop_fixture(%Drop{}, user)

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

    test "edited comments show 'edited' flag", %{conn: conn, drop: drop, user: user} do
      {:ok, comment} =
        Comments.create_comment(drop, user, nil, %{body: "Initial body"})

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      view
      |> form("#edit-comment-form-#{comment.id}",
        comment: %{body: "Updated body"}
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
        comment: %{body: ""}
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

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      form_id = "reply-form-#{comment.id}"

      view
      |> form("##{form_id}",
        comment: %{body: "Good"}
      )
      |> render_change()

      assert_push_event(view, "reply_char_count", %{
        count: 4,
        form_id: _form_id
      })
    end

    test "users can reply to a comment", %{
      conn: conn,
      drop: drop,
      user: user
    } do
      {:ok, comment} =
        Comments.create_comment(drop, user, nil, %{body: "Top level"})

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      view
      |> form("#reply-form-#{comment.id}",
        comment: %{body: "A reply"}
      )
      |> render_submit()

      assert render(view) =~ "A reply"
    end

    test "users can delete a comment", %{
      conn: conn,
      drop: drop,
      user: user
    } do
      {:ok, comment} =
        Comments.create_comment(drop, user, nil, %{body: "Delete me"})

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      assert render(view) =~ "Delete me"

      render_hook(view, :delete_comment, %{comment_id: comment.id})

      refute render(view) =~ "Delete me"
    end

    test "user can load more comments", %{
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
      |> element("#load-more-comments")
      |> render_click()

      assert render(view) =~ "Comment 15"
    end

    test "cancel button clears textarea content", %{
      conn: conn,
      drop: drop
    } do
      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      unique = "Some unique draft text #{System.unique_integer()}"

      view
      |> form("#new-comment-form",
        comment: %{body: unique}
      )
      |> render_change()

      view
      |> element("#new-comment-form-cancel-btn")
      |> render_click()

      refute render(view) =~ unique
    end

    test "mounts the edit form if the user is the comment author", %{
      conn: conn,
      drop: drop,
      user: user
    } do
      comment = comment_fixture(drop, user, nil)

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      assert view
             |> element("#edit-comment-form-#{comment.id}")
             |> has_element?()
    end

    test "does not mount the edit form if the user is not the comment author", %{
      conn: conn,
      drop: drop,
      user: user
    } do
      comment = comment_fixture(drop, user, nil)
      another_user = user_fixture()
      conn = sign_in_user(conn, another_user)

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      refute view
             |> element("#edit-comment-form-#{comment.id}")
             |> has_element?()
    end

    test "mounts the reply form for top-level comments only", %{
      conn: conn,
      drop: drop,
      user: user
    } do
      top_level_comment = comment_fixture(drop, user, nil)
      reply_comment = comment_fixture(drop, user, top_level_comment)

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      assert view
             |> element("#reply-form-#{top_level_comment.id}")
             |> has_element?()

      refute view
             |> element("#reply-form-#{reply_comment.id}")
             |> has_element?()
    end
  end
end
