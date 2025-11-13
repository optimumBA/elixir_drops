defmodule ElixirDropsWeb.DropLiveShowTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
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

    test "valid body adds a comment", %{conn: conn, drop: drop, user: user} do
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

    test "invalid body adds an error message to the page", %{conn: conn, drop: drop} do
      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      view
      |> form("#new-comment-form",
        comment: %{body: ""}
      )
      |> render_submit()

      updated_html = render(view)
      assert updated_html =~ "Failed to add your comment"
      assert updated_html =~ "Comments (0)"
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

    test "user can edit a comment and see edited flag", %{conn: conn, drop: drop, user: user} do
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

    test "user can reply to a comment", %{
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

    test "deletes comment and removes it from the UI", %{
      conn: conn,
      drop: drop,
      user: user
    } do
      {:ok, comment} =
        Comments.create_comment(drop, user, nil, %{body: "Delete me"})

      {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")

      view
      |> element("#trigger-comment-deletion-#{comment.id}", "Delete comment")
      |> render_click()

      view
      |> element("#confirm-comment-deletion-#{comment.id}", "Confirm")
      |> render_click()

      refute render(view) =~ "Delete me"
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
      |> element("#new-comment-form button", "Cancel")
      |> render_click()

      refute render(view) =~ unique
    end
  end
end
