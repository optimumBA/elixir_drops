defmodule AuthorizeCommentDeletionByUserAndDropTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.CommentsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Comments
  alias ElixirDrops.Comments.Comment
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Repo

  defp rows(drop_ids) do
    Comment
    |> Repo.all()
    |> Enum.filter(&(&1.drop_id in drop_ids))
    |> Enum.map(&{&1.id, &1.user_id, &1.drop_id, &1.parent_id, &1.body})
    |> Enum.sort()
  end

  defp counts(drops), do: Enum.map(drops, &Comments.count_drop_comments(&1.id))

  defp forge_delete(view, comment) do
    send_event(view, comment)
    assert Process.alive?(view.pid)
  end

  defp send_event(view, comment), do: render_hook(view, :delete_comment, %{comment_id: comment.id})

  defp assert_rejected(conn, viewed_drop, target, drops) do
    ids = Enum.map(drops, & &1.id)
    before_rows = rows(ids)
    before_counts = counts(drops)

    {:ok, view, _html} = live(conn, "/d/#{viewed_drop.short_id}")
    before_html = render(view)
    assert before_html =~ target.body

    forge_delete(view, target)

    assert Repo.get(Comment, target.id)
    assert rows(ids) == before_rows
    assert counts(drops) == before_counts
    assert render(view) =~ target.body
  end

  test "guest deletion is rejected without mutation", %{conn: conn} do
    author = user_fixture()
    drop = drop_fixture(%Drop{}, author)
    comment = comment_fixture(drop, author, nil, %{body: "guest target body"})
    _reply = comment_fixture(drop, author, comment, %{body: "guest reply body"})

    assert_rejected(conn, drop, comment, [drop])
  end

  test "other author comment is rejected without mutation", %{conn: conn} do
    user_a = user_fixture()
    user_b = user_fixture()
    drop = drop_fixture(%Drop{}, user_b)
    comment = comment_fixture(drop, user_b, nil, %{body: "user b body"})
    _reply = comment_fixture(drop, user_b, comment, %{body: "user b reply body"})
    _own = comment_fixture(drop, user_a, nil, %{body: "user a body"})

    assert_rejected(sign_in_user(conn, user_a), drop, comment, [drop])
  end

  test "other Drop comment is rejected without mutation", %{conn: conn} do
    user_a = user_fixture()
    drop_x = drop_fixture(%Drop{}, user_a)
    drop_y = drop_fixture(%Drop{}, user_a)
    _on_x = comment_fixture(drop_x, user_a, nil, %{body: "comment on x"})
    comment_y = comment_fixture(drop_y, user_a, nil, %{body: "comment on y"})
    _reply_y = comment_fixture(drop_y, user_a, comment_y, %{body: "reply on y"})

    conn = sign_in_user(conn, user_a)
    before_rows = rows([drop_x.id, drop_y.id])
    before_counts = counts([drop_x, drop_y])

    {:ok, view, _html} = live(conn, "/d/#{drop_x.short_id}")
    forge_delete(view, comment_y)

    assert Repo.get(Comment, comment_y.id)
    assert rows([drop_x.id, drop_y.id]) == before_rows
    assert counts([drop_x, drop_y]) == before_counts
    refute render(view) =~ "comment on y"
    assert render(view) =~ "comment on x"
  end

  test "author deletes a top-level comment", %{conn: conn} do
    user_a = user_fixture()
    drop = drop_fixture(%Drop{}, user_a)
    other_drop = drop_fixture(%Drop{}, user_a)
    comment = comment_fixture(drop, user_a, nil, %{body: "delete top body"})
    reply = comment_fixture(drop, user_a, comment, %{body: "cascade reply body"})
    _keep = comment_fixture(drop, user_a, nil, %{body: "keep top body"})
    other = comment_fixture(other_drop, user_a, nil, %{body: "other drop body"})

    {:ok, view, _html} = live(sign_in_user(conn, user_a), "/d/#{drop.short_id}")
    assert render(view) =~ "delete top body"

    send_event(view, comment)

    refute Repo.get(Comment, comment.id)
    refute Repo.get(Comment, reply.id)
    assert Repo.get(Comment, other.id)
    assert counts([drop, other_drop]) == [1, 1]
    html = render(view)
    refute html =~ "delete top body"
    refute html =~ "cascade reply body"
    assert html =~ "keep top body"
  end

  test "author deletes a reply", %{conn: conn} do
    user_a = user_fixture()
    user_b = user_fixture()
    drop = drop_fixture(%Drop{}, user_b)
    parent = comment_fixture(drop, user_b, nil, %{body: "parent stays body"})
    reply = comment_fixture(drop, user_a, parent, %{body: "reply goes body"})
    sibling = comment_fixture(drop, user_b, parent, %{body: "sibling stays body"})

    {:ok, view, _html} = live(sign_in_user(conn, user_a), "/d/#{drop.short_id}")
    assert render(view) =~ "reply goes body"

    send_event(view, reply)

    refute Repo.get(Comment, reply.id)
    assert Repo.get(Comment, parent.id)
    assert Repo.get(Comment, sibling.id)
    assert counts([drop]) == [2]
    html = render(view)
    refute html =~ "reply goes body"
    assert html =~ "parent stays body"
    assert html =~ "sibling stays body"
  end
end
