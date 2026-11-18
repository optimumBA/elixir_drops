defmodule ScopeCommentEditsAndRepliesToDropTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.CommentsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Comments
  alias ElixirDrops.Comments.Comment
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Notifications.Notification
  alias ElixirDrops.Repo

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)
  end

  defp stored(comment), do: Repo.get(Comment, comment.id)

  test "author edits own comment on its Drop" do
    author = user_fixture()
    drop = drop_fixture(%Drop{}, author)
    comment = comment_fixture(drop, author, nil, %{body: "original body"})
    assert comment.edited_at == nil

    assert {:ok, %Comment{} = edited} =
             Comments.edit_comment(author, drop, comment.id, %{"body" => "new body"})

    assert edited.id == comment.id
    assert edited.body == "new body"
    assert %DateTime{} = edited.edited_at

    saved = stored(comment)
    assert saved.body == "new body"
    assert %DateTime{} = saved.edited_at
    assert saved.user_id == author.id
    assert saved.drop_id == drop.id
  end

  test "other user, other Drop, unknown and malformed ids are not found and change nothing" do
    author = user_fixture()
    intruder = user_fixture()
    drop = drop_fixture(%Drop{}, author)
    other_drop = drop_fixture(%Drop{}, author)
    mine = comment_fixture(drop, author, nil, %{body: "mine body"})
    on_other_drop = comment_fixture(other_drop, author, nil, %{body: "other drop body"})
    before_mine = stored(mine)
    before_other = stored(on_other_drop)
    attrs = %{"body" => "forged body"}

    assert {:error, :not_found} = Comments.edit_comment(intruder, drop, mine.id, attrs)
    assert {:error, :not_found} = Comments.edit_comment(author, drop, on_other_drop.id, attrs)
    assert {:error, :not_found} = Comments.edit_comment(author, drop, Ecto.UUID.generate(), attrs)
    assert {:error, :not_found} = Comments.edit_comment(author, drop, "not-a-uuid", attrs)
    assert {:error, :not_found} = Comments.edit_comment(author, drop, nil, attrs)

    assert stored(mine) == before_mine
    assert stored(on_other_drop) == before_other
  end

  test "reply under another Drop's parent is refused and same-Drop reply works" do
    author = user_fixture()
    replier = user_fixture()
    drop = drop_fixture(%Drop{}, author)
    other_drop = drop_fixture(%Drop{}, author)
    same_parent = comment_fixture(drop, author, nil, %{body: "same drop parent"})
    foreign_parent = comment_fixture(other_drop, author, nil, %{body: "foreign parent"})
    comments_before = Repo.aggregate(Comment, :count)
    notifications_before = Repo.aggregate(Notification, :count)

    assert {:error, %Ecto.Changeset{} = changeset} =
             Comments.create_comment(drop, replier, foreign_parent, %{body: "misplaced reply"})

    assert "must belong to the same drop" in errors_on(changeset).parent_id
    assert Repo.aggregate(Comment, :count) == comments_before
    assert Repo.aggregate(Notification, :count) == notifications_before
    assert Comments.count_drop_comments(drop.id) == 1

    assert {:ok, %Comment{} = reply} =
             Comments.create_comment(drop, replier, same_parent, %{body: "proper reply"})

    assert reply.parent_id == same_parent.id
    assert reply.drop_id == drop.id
    assert Repo.aggregate(Comment, :count) == comments_before + 1

    assert {:error, %Ecto.Changeset{} = nested} =
             Comments.create_comment(drop, replier, reply, %{body: "reply to reply"})

    assert "replies cannot have replies" in errors_on(nested).parent_id
    assert Repo.aggregate(Comment, :count) == comments_before + 1
  end

  test "forged edit event changes nothing and the author edit still works", %{conn: conn} do
    user_a = user_fixture()
    user_b = user_fixture()
    drop = drop_fixture(%Drop{}, user_a)
    comment_a = comment_fixture(drop, user_a, nil, %{body: "alpha original"})
    comment_b = comment_fixture(drop, user_b, nil, %{body: "beta original"})
    before_a = stored(comment_a)
    before_b = stored(comment_b)

    {:ok, view, _html} = live(sign_in_user(conn, user_b), "/d/#{drop.short_id}")

    view
    |> with_target("#edit-comment-form-#{comment_b.id}")
    |> render_hook("update_comment", %{
      "comment" => %{"body" => "hijacked text"},
      "comment_id" => comment_a.id
    })

    html = render(view)
    assert Process.alive?(view.pid)
    assert stored(comment_a) == before_a
    assert stored(comment_b) == before_b
    assert html =~ "alpha original"
    refute html =~ "hijacked text"
    assert html =~ "That comment could not be edited."

    {:ok, view_a, _html} = live(sign_in_user(conn, user_a), "/d/#{drop.short_id}")

    view_a
    |> form("#edit-comment-form-#{comment_a.id}", comment: %{body: "alpha revised"})
    |> render_submit()

    html_a = render(view_a)
    assert html_a =~ "alpha revised"
    assert html_a =~ "Edited"
    refute html_a =~ "That comment could not be edited."
    saved = stored(comment_a)
    assert saved.body == "alpha revised"
    assert %DateTime{} = saved.edited_at
    assert stored(comment_b) == before_b
  end
end
