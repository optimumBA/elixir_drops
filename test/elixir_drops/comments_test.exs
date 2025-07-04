defmodule ElixirDrops.CommentsTest do
  use ElixirDrops.DataCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.CommentsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Comments

  describe "comments" do
    alias ElixirDrops.Comments.Comment

    @invalid_attrs %{body: nil}

    test "list_drop_comments/2 returns all comments for a drop" do
      user = user_fixture()
      drop = drop_fixture(%ElixirDrops.Drops.Drop{}, user)
      comment1 = comment_fixture(%{drop: drop, user: user})
      comment2 = comment_fixture(%{drop: drop, user: user})

      comments = Comments.list_drop_comments(drop.id)
      comment_ids = Enum.map(comments, & &1.id)

      assert length(comments) == 2
      assert comment1.id in comment_ids
      assert comment2.id in comment_ids
    end

    test "list_drop_comments/2 does not return comments from other drops" do
      user = user_fixture()
      drop1 = drop_fixture(%ElixirDrops.Drops.Drop{}, user)
      drop2 = drop_fixture(%ElixirDrops.Drops.Drop{}, user)

      _comment1 = comment_fixture(%{drop: drop1, user: user})
      _comment2 = comment_fixture(%{drop: drop2, user: user})

      comments = Comments.list_drop_comments(drop1.id)

      assert length(comments) == 1
    end

    test "list_drop_comments/2 respects limit" do
      user = user_fixture()
      drop = drop_fixture(%ElixirDrops.Drops.Drop{}, user)

      # Create 5 comments
      for _ <- 1..5 do
        comment_fixture(%{drop: drop, user: user})
      end

      comments = Comments.list_drop_comments(drop.id, limit: 3)

      assert length(comments) == 3
    end

    test "get_comment!/1 returns the comment with given id" do
      comment = comment_fixture()
      fetched_comment = Comments.get_comment!(comment.id)
      assert fetched_comment.id == comment.id
    end

    test "count_drop_comments/1 returns the correct count" do
      user = user_fixture()
      drop = drop_fixture(%ElixirDrops.Drops.Drop{}, user)

      assert Comments.count_drop_comments(drop.id) == 0

      comment_fixture(%{drop: drop, user: user})
      comment_fixture(%{drop: drop, user: user})

      assert Comments.count_drop_comments(drop.id) == 2
    end

    test "count_drop_comments/1 excludes deleted comments" do
      user = user_fixture()
      drop = drop_fixture(%ElixirDrops.Drops.Drop{}, user)
      comment = comment_fixture(%{drop: drop, user: user})

      assert Comments.count_drop_comments(drop.id) == 1

      Comments.delete_comment(comment)

      assert Comments.count_drop_comments(drop.id) == 0
    end

    test "create_comment/1 with valid data creates a comment" do
      user = user_fixture()
      drop = drop_fixture(%ElixirDrops.Drops.Drop{}, user)

      valid_attrs = %{
        body: "**some** body",
        drop_id: drop.id,
        user_id: user.id
      }

      assert {:ok, %Comment{} = comment} = Comments.create_comment(valid_attrs)
      assert comment.body == "**some** body"
      assert comment.body_html =~ "<strong>some</strong>"
    end

    test "create_comment/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Comments.create_comment(@invalid_attrs)
    end

    test "create_comment/1 validates body length" do
      user = user_fixture()
      drop = drop_fixture(%ElixirDrops.Drops.Drop{}, user)

      long_body = String.duplicate("a", 1001)

      attrs = %{
        body: long_body,
        drop_id: drop.id,
        user_id: user.id
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Comments.create_comment(attrs)
      assert "should be at most 1000 character(s)" in errors_on(changeset).body
    end

    test "create_comment/1 prevents replies to replies" do
      comment = comment_fixture()
      reply = reply_fixture(comment)
      user = user_fixture(%{github_id: 999_997})

      attrs = %{
        body: "reply to reply",
        drop_id: comment.drop_id,
        parent_id: reply.id,
        user_id: user.id
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Comments.create_comment(attrs)
      assert "replies cannot have replies" in errors_on(changeset).parent_id
    end

    test "update_comment/2 with valid data updates the comment" do
      comment = comment_fixture()
      update_attrs = %{body: "some updated body"}

      assert {:ok, %Comment{} = comment} = Comments.update_comment(comment, update_attrs)
      assert comment.body == "some updated body"
      assert comment.edited_at != nil
    end

    test "update_comment/2 with invalid data returns error changeset" do
      comment = comment_fixture()
      assert {:error, %Ecto.Changeset{}} = Comments.update_comment(comment, @invalid_attrs)
      original_comment = Comments.get_comment!(comment.id)
      assert comment.body == original_comment.body
    end

    test "delete_comment/1 soft deletes the comment" do
      comment = comment_fixture()
      assert {:ok, %Comment{} = deleted_comment} = Comments.delete_comment(comment)
      assert deleted_comment.deleted_at != nil

      # Comment still exists but is marked as deleted
      fetched_comment = Comments.get_comment!(comment.id)
      assert fetched_comment.deleted_at != nil
    end

    test "change_comment/1 returns a comment changeset" do
      comment = comment_fixture()
      assert %Ecto.Changeset{} = Comments.change_comment(comment)
    end

    test "can_edit_comment?/2 returns true for comment owner" do
      comment = comment_fixture()
      assert Comments.can_edit_comment?(comment, comment.user_id)
    end

    test "can_edit_comment?/2 returns false for different user" do
      first_user = user_fixture()
      second_user = user_fixture(%{github_id: 999_999})
      comment = comment_fixture(%{user: first_user})
      refute Comments.can_edit_comment?(comment, second_user.id)
    end

    test "can_delete_comment?/2 returns true for comment owner" do
      comment = comment_fixture()
      assert Comments.can_delete_comment?(comment, comment.user_id)
    end

    test "can_delete_comment?/2 returns false for different user" do
      first_user = user_fixture()
      second_user = user_fixture(%{github_id: 999_998})
      comment = comment_fixture(%{user: first_user})
      refute Comments.can_delete_comment?(comment, second_user.id)
    end
  end
end
