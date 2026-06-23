defmodule ElixirDropsWeb.DropLiveShowTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.CommentsFixtures
  import ElixirDrops.DropsFixtures
  import ElixirDrops.NotificationsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Comments
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Notifications

  defp create_drop_setup(%{conn: conn}) do
    user = user_fixture()
    drop = drop_fixture(%Drop{}, user)
    conn = sign_in_user(conn, user)

    %{conn: conn, drop: drop, user: user}
  end

  describe "/d/short_id" do
    setup [:create_drop_setup]

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

    test "commenting sends a notification to the drop author", %{
      conn: conn
    } do
      drop_author = user_fixture()
      drop = drop_fixture(%Drop{}, drop_author)

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      view
      |> form("#new-comment-form",
        comment: %{body: "This is my test comment"}
      )
      |> render_submit()

      # Flush pending handle_info({:new_comment, ...}) so notifications are persisted to DB
      render(view)

      conn = sign_in_user(conn, drop_author)

      {:ok, view_2, _html} = live(conn, ~p"/d/#{drop.short_id}")

      assert view_2
             |> element("#notifications-count")
             |> render() =~ "1"
    end

    test "receives live notification broadcasts while viewing a drop", %{
      conn: conn,
      drop: drop,
      user: user
    } do
      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      # No notifications yet — the count badge only renders when > 0.
      refute has_element?(view, "#notifications-count")

      # Broadcasting through PubSub (not send/2 to the pid) is what proves the
      # LiveView actually subscribed. This is the resume-sensitive path: subscribe
      # must happen on connect, because on a resumed warm connect mount/3 and
      # handle_params/3 are skipped — connection-only work belongs in on_connect/1.
      actor = user_fixture()
      comment = comment_fixture(drop, actor)
      notification = notification_fixture(actor, user, comment)
      Notifications.broadcast(notification)

      assert has_element?(view, "#notifications-count", "1")
    end

    test "replying to a comment sends a notification to both the drop author and the comment author",
         %{
           conn: conn
         } do
      drop_author = user_fixture()
      parent_comment_author = user_fixture()
      drop = drop_fixture(%Drop{}, drop_author)

      {:ok, parent_comment} =
        Comments.create_comment(drop, parent_comment_author, nil, %{body: "Top level"})

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      view
      |> form("#reply-form-#{parent_comment.id}",
        comment: %{body: "A reply"}
      )
      |> render_submit()

      # Flush pending handle_info({:new_comment, ...}) so notifications are persisted to DB
      render(view)

      conn_2 = sign_in_user(conn, drop_author)

      {:ok, view_2, _html} = live(conn_2, ~p"/d/#{drop.short_id}")

      assert view_2
             |> element("#notifications-container")
             |> render() =~ "some_name commented on your post -"

      conn_3 = sign_in_user(conn, parent_comment_author)

      {:ok, view_3, _html} = live(conn_3, ~p"/d/#{drop.short_id}")

      assert view_3
             |> element("#notifications-container")
             |> render() =~ "some_name replied to your comment on -"
    end

    test "replying to a comment sends only one notification to a drop author if they are the comment's author",
         %{
           conn: conn
         } do
      drop_author = user_fixture()
      drop = drop_fixture(%Drop{}, drop_author)

      {:ok, parent_comment} =
        Comments.create_comment(drop, drop_author, nil, %{body: "Top level"})

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      # The reply form is a LiveComponent that sends {:new_comment, ...} to the
      # parent LiveView, which creates the comment and notifications in handle_info.
      # render_submit/1 only awaits the component's event, not the parent's async
      # handle_info, so subscribe and wait for the notification broadcast to be sure
      # it has been persisted before we read it back through a fresh mount.
      Notifications.subscribe(drop_author.id)

      view
      |> form("#reply-form-#{parent_comment.id}",
        comment: %{body: "A reply"}
      )
      |> render_submit()

      assert_receive {:new_notification, _notification}

      conn = sign_in_user(conn, drop_author)

      {:ok, view_2, _html} = live(conn, ~p"/d/#{drop.short_id}")

      assert view_2
             |> element("#notifications-count")
             |> render() =~ "1"

      refute view_2
             |> element("#notifications-container")
             |> render() =~ "some_name commented on your post -"

      assert view_2
             |> element("#notifications-container")
             |> render() =~ "some_name replied to your comment on -"
    end

    test "user can mark notifications as read",
         %{
           conn: conn
         } do
      drop_author = user_fixture()
      drop = drop_fixture(%Drop{}, drop_author)

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      view
      |> form("#new-comment-form",
        comment: %{body: "This is my test comment"}
      )
      |> render_submit()

      conn = sign_in_user(conn, drop_author)

      {:ok, view_2, _html} = live(conn, ~p"/d/#{drop.short_id}")

      assert view_2
             |> element("#notifications-count")
             |> render() =~ "1"

      view_2
      |> element("#mark-notifications-as-read")
      |> render_click()

      refute view_2
             |> element("#notifications-count")
             |> has_element?()
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

    test "sign in link in comment section uses encoded return_to value matching navbar link format",
         %{drop: drop} do
      conn = build_conn()
      {:ok, _view, html} = live(conn, ~p"/d/#{drop.short_id}")

      # The ~p sigil encodes path values, so /d/short_id becomes %2Fd%2Fshort_id.
      # All sign-in links should consistently encode the return_to value.
      # The comment section uses string concatenation which skips encoding, producing an
      # unencoded href="/auth/github?return_to=/d/..." instead.
      encoded_link = ~s(href="/auth/github?return_to=%2Fd%2F#{drop.short_id}")
      unencoded_link = ~s(href="/auth/github?return_to=/d/#{drop.short_id}")

      assert html =~ encoded_link
      refute html =~ unencoded_link
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
