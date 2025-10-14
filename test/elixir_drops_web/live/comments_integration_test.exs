defmodule ElixirDropsWeb.CommentsIntegrationTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Comments

  describe "full comments integration" do
    test "complete commenting workflow", %{conn: conn} do
      # Create user and drop
      user = user_fixture()
      drop = drop_fixture(%ElixirDrops.Drops.Drop{}, user)

      # Sign in user
      conn = sign_in_user(conn, user)

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
  end
end
