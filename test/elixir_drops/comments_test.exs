defmodule ElixirDrops.CommentsTest do
  use ElixirDrops.DataCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.CommentsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Comments
  alias ElixirDrops.Comments.Comment
  alias ElixirDrops.Drops.Drop
  alias Phoenix.Socket.Broadcast

  @invalid_attrs %{body: nil}

  setup do
    user = user_fixture()
    drop = drop_fixture(%Drop{}, user)

    %{drop: drop, user: user}
  end

  describe "subscribe_to_drop_comments/1" do
    test "subscribes to comment events for a drop", %{drop: drop} do
      assert :ok = Comments.subscribe_to_drop_comments(drop.id)
    end
  end

  describe "list_drop_comments/2" do
    test "returns all comments for a drop", %{drop: drop, user: user} do
      for _comment <- 1..2 do
        comment_fixture(drop, user)
      end

      comments = Comments.list_drop_comments(drop.id)

      assert length(comments) == 2
    end

    test "does not return comments from other drops", %{user: user} do
      drop1 = drop_fixture(%Drop{}, user)
      drop2 = drop_fixture(%Drop{}, user)

      _comment1 = comment_fixture(drop1, user)
      _comment2 = comment_fixture(drop2, user)

      comments = Comments.list_drop_comments(drop1.id)

      assert length(comments) == 1
    end

    test "respects limit option", %{drop: drop, user: user} do
      for _ <- 1..5 do
        comment_fixture(drop, user)
      end

      comments = Comments.list_drop_comments(drop.id, limit: 3)

      assert length(comments) == 3
    end

    test "respects offset option", %{drop: drop, user: user} do
      comments_created =
        for _ <- 1..5 do
          comment_fixture(drop, user)
        end

      comments = Comments.list_drop_comments(drop.id, limit: 2, offset: 2)

      assert length(comments) == 2
      comment_ids = Enum.map(comments, & &1.id)
      created_ids = Enum.map(comments_created, & &1.id)

      assert Enum.all?(comment_ids, &(&1 in created_ids))
    end

    test "only returns top-level comments (no replies)", %{drop: drop, user: user} do
      parent_comment = comment_fixture(drop, user)
      _reply = comment_fixture(drop, user, parent_comment)

      comments = Comments.list_drop_comments(drop.id)

      assert length(comments) == 1
      assert hd(comments).id == parent_comment.id
    end

    test "preloads drop, user, and replies associations", %{drop: drop, user: user} do
      parent_comment = comment_fixture(drop, user)
      reply = comment_fixture(drop, user, parent_comment)

      comments = Comments.list_drop_comments(drop.id)
      comment = hd(comments)

      assert Ecto.assoc_loaded?(comment.drop)
      assert Ecto.assoc_loaded?(comment.user)
      assert Ecto.assoc_loaded?(comment.replies)
    end
  end

  describe "get_comment!/1" do
    test "returns the comment with given id", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)

      fetched_comment = Comments.get_comment!(comment.id)

      assert fetched_comment.id == comment.id
      assert fetched_comment.body == comment.body
    end

    test "preloads user and drop associations", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)

      fetched_comment = Comments.get_comment!(comment.id)

      assert Ecto.assoc_loaded?(fetched_comment.user)
      assert Ecto.assoc_loaded?(fetched_comment.drop)
    end

    test "raises Ecto.NoResultsError for non-existent comment" do
      non_existent_id = Ecto.UUID.generate()

      assert_raise Ecto.NoResultsError, fn ->
        Comments.get_comment!(non_existent_id)
      end
    end
  end

  describe "count_drop_comments/1" do
    test "returns 0 for drop with no comments", %{drop: drop} do
      assert Comments.count_drop_comments(drop.id) == 0
    end

    test "returns correct count for drop with comments", %{drop: drop, user: user} do
      for _comment <- 1..2 do
        comment_fixture(drop, user)
      end

      assert Comments.count_drop_comments(drop.id) == 2
    end

    test "does not count comments from other drops", %{user: user} do
      drop1 = drop_fixture(%Drop{}, user)
      drop2 = drop_fixture(%Drop{}, user)

      comment_fixture(drop1, user)

      for _comment <- 1..2 do
        comment_fixture(drop2, user)
      end

      assert Comments.count_drop_comments(drop1.id) == 1
      assert Comments.count_drop_comments(drop2.id) == 2
    end

    test "excludes deleted comments from count", %{drop: drop, user: user} do
      comment1 = comment_fixture(drop, user)
      _comment2 = comment_fixture(drop, user)

      assert Comments.count_drop_comments(drop.id) == 2

      Comments.delete_comment(comment1)

      assert Comments.count_drop_comments(drop.id) == 1
    end

    test "includes replies in the total count", %{drop: drop, user: user} do
      parent_comment = comment_fixture(drop, user)
      comment_fixture(drop, user, parent_comment)

      assert Comments.count_drop_comments(drop.id) == 2
    end
  end

  describe "create_comment/4" do
    test "creates a comment with valid data", %{drop: drop, user: user} do
      attrs = %{body: "**some** body"}

      assert {:ok, %Comment{} = comment} = Comments.create_comment(drop, user, nil, attrs)
      assert comment.body == "**some** body"
      assert comment.drop_id == drop.id
      assert comment.user_id == user.id
      assert comment.parent_id == nil
    end

    test "creates a reply comment with parent", %{drop: drop, user: user} do
      parent_comment = comment_fixture(drop, user)
      attrs = %{body: "This is a reply"}

      assert {:ok, %Comment{} = reply} =
               Comments.create_comment(drop, user, parent_comment, attrs)

      assert reply.body == "This is a reply"
      assert reply.parent_id == parent_comment.id
      assert reply.drop_id == drop.id
      assert reply.user_id == user.id
    end

    test "returns error changeset with invalid data", %{drop: drop, user: user} do
      assert {:error, %Ecto.Changeset{}} =
               Comments.create_comment(drop, user, nil, @invalid_attrs)
    end

    test "validates body length", %{drop: drop, user: user} do
      long_body = String.duplicate("a", 1001)
      attrs = %{body: long_body}

      assert {:error, %Ecto.Changeset{} = changeset} =
               Comments.create_comment(drop, user, nil, attrs)

      assert "should be at most 1000 character(s)" in errors_on(changeset).body
    end

    test "broadcasts comment event after successful creation", %{drop: drop, user: user} do
      attrs = %{body: "Test comment"}

      Comments.subscribe_to_drop_comments(drop.id)

      assert {:ok, comment} = Comments.create_comment(drop, user, nil, attrs)

      assert_received %Broadcast{
        topic: _,
        event: "comment_event",
        payload: %{comment: %Comment{id: comment_id}, event: :created}
      }

      assert comment_id == comment.id
    end

    test "preloads associations in returned comment", %{drop: drop, user: user} do
      attrs = %{body: "Test comment"}

      assert {:ok, comment} = Comments.create_comment(drop, user, nil, attrs)

      assert Ecto.assoc_loaded?(comment.user)
      assert Ecto.assoc_loaded?(comment.drop)
    end
  end

  describe "update_comment/2" do
    test "updates comment with valid data", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)
      update_attrs = %{body: "some updated body"}

      assert {:ok, %Comment{} = updated_comment} = Comments.update_comment(comment, update_attrs)
      assert updated_comment.body == "some updated body"
      assert updated_comment.id == comment.id
    end

    test "returns error changeset with invalid data", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)

      assert {:error, %Ecto.Changeset{}} = Comments.update_comment(comment, @invalid_attrs)

      original_comment = Comments.get_comment!(comment.id)
      assert comment.body == original_comment.body
    end

    test "validates body length on update", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)
      long_body = String.duplicate("a", 1001)
      update_attrs = %{body: long_body}

      assert {:error, %Ecto.Changeset{} = changeset} =
               Comments.update_comment(comment, update_attrs)

      assert "should be at most 1000 character(s)" in errors_on(changeset).body
    end

    test "broadcasts comment event after successful update", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)
      update_attrs = %{body: "updated body"}

      Comments.subscribe_to_drop_comments(drop.id)

      assert {:ok, updated_comment} = Comments.update_comment(comment, update_attrs)

      assert_received %Broadcast{
        event: "comment_event",
        payload: %{comment: %Comment{id: comment_id}, event: :updated}
      }

      assert comment_id == updated_comment.id
    end

    test "preloads associations in returned comment", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)
      update_attrs = %{body: "updated body"}

      assert {:ok, updated_comment} = Comments.update_comment(comment, update_attrs)

      assert Ecto.assoc_loaded?(updated_comment.user)
      assert Ecto.assoc_loaded?(updated_comment.drop)
    end
  end

  describe "delete_comment/1" do
    test "soft deletes a comment", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)

      assert {:ok, %Comment{} = deleted_comment} = Comments.delete_comment(comment)
      assert deleted_comment.deleted_at != nil
      assert deleted_comment.id == comment.id
    end

    test "comment still exists but is marked as deleted", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)

      assert {:ok, _deleted_comment} = Comments.delete_comment(comment)

      fetched_comment = Comments.get_comment!(comment.id)
      assert fetched_comment.deleted_at != nil
      assert fetched_comment.id == comment.id
    end

    test "broadcasts comment event after successful deletion", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)

      Comments.subscribe_to_drop_comments(drop.id)

      assert {:ok, deleted_comment} = Comments.delete_comment(comment)

      assert_received %Broadcast{
        event: "comment_event",
        payload: %{comment: %Comment{id: comment_id}, event: :deleted}
      }

      assert comment_id == deleted_comment.id
    end

    test "preloads associations in returned comment", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)

      assert {:ok, deleted_comment} = Comments.delete_comment(comment)

      assert Ecto.assoc_loaded?(deleted_comment.user)
      assert Ecto.assoc_loaded?(deleted_comment.drop)
    end

    test "deleted comment is excluded from count", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)

      assert Comments.count_drop_comments(drop.id) == 1

      Comments.delete_comment(comment)

      assert Comments.count_drop_comments(drop.id) == 0
    end
  end

  describe "change_comment/2" do
    test "returns a comment changeset with no changes", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)

      changeset = Comments.change_comment(comment)

      assert %Ecto.Changeset{} = changeset
      assert changeset.data == comment
      assert changeset.changes == %{}
      assert changeset.valid?
    end

    test "returns a comment changeset with given attributes", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)
      attrs = %{body: "new body"}

      changeset = Comments.change_comment(comment, attrs)

      assert %Ecto.Changeset{} = changeset
      assert changeset.data == comment
      assert changeset.changes.body == "new body"
    end

    test "validates changeset with invalid attributes", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)
      invalid_attrs = %{body: nil}

      changeset = Comments.change_comment(comment, invalid_attrs)

      assert %Ecto.Changeset{} = changeset
      refute changeset.valid?
    end

    test "validates changeset with long body", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)
      long_body = String.duplicate("a", 1001)
      attrs = %{body: long_body}

      changeset = Comments.change_comment(comment, attrs)

      assert %Ecto.Changeset{} = changeset
      refute changeset.valid?
      assert "should be at most 1000 character(s)" in errors_on(changeset).body
    end
  end

  describe "can_edit_comment?/2" do
    test "returns true for comment owner", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)

      assert Comments.can_edit_comment?(comment, user.id)
    end

    test "returns false for different user", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)
      another_user = user_fixture(%{github_id: 999_998})

      refute Comments.can_edit_comment?(comment, another_user.id)
    end

    test "returns false for nil user_id", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)

      refute Comments.can_edit_comment?(comment, nil)
    end
  end

  describe "can_delete_comment?/2" do
    test "returns true for comment owner", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)

      assert Comments.can_delete_comment?(comment, user.id)
    end

    test "returns false for different user", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)
      another_user = user_fixture(%{github_id: 999_999})

      refute Comments.can_delete_comment?(comment, another_user.id)
    end

    test "returns false for nil user_id", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)

      refute Comments.can_delete_comment?(comment, nil)
    end
  end
end
