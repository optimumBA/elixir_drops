defmodule ElixirDrops.CommentsTest do
  use ElixirDrops.DataCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.CommentsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Comments
  alias ElixirDrops.Comments.Comment
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Repo

  @invalid_attrs %{body: nil}

  defp create_drop_setup(_attrs) do
    user = user_fixture()
    drop = drop_fixture(%Drop{}, user)

    %{drop: drop, user: user}
  end

  describe "list_drop_comments/2" do
    setup [:create_drop_setup]

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

    test "respects the limit option", %{drop: drop, user: user} do
      for _i <- 1..5 do
        comment_fixture(drop, user)
      end

      comments = Comments.list_drop_comments(drop.id, limit: 3)

      assert length(comments) == 3
    end

    test "respects the offset option", %{drop: drop, user: user} do
      comments_created =
        for _num <- 1..5 do
          comment_fixture(drop, user)
        end

      comments = Comments.list_drop_comments(drop.id, limit: 2, offset: 3)

      assert length(comments) == 2
      fetched_comment_ids = Enum.map(comments, & &1.id)

      created_comment_ids =
        comments_created
        |> Enum.sort_by(&{&1.inserted_at, &1.id}, :desc)
        |> Enum.drop(3)
        |> Enum.map(& &1.id)

      assert fetched_comment_ids == created_comment_ids
    end

    test "only returns top-level comments (no replies)", %{drop: drop, user: user} do
      parent_comment = comment_fixture(drop, user)
      _reply = comment_fixture(drop, user, parent_comment)

      comments = Comments.list_drop_comments(drop.id)

      assert length(comments) == 1
      assert hd(comments).id == parent_comment.id
    end

    test "preloads user, and replies associations", %{drop: drop, user: user} do
      parent_comment = comment_fixture(drop, user)
      _reply = comment_fixture(drop, user, parent_comment)

      comments = Comments.list_drop_comments(drop.id)
      comment = hd(comments)

      assert Ecto.assoc_loaded?(comment.user)
      assert Ecto.assoc_loaded?(comment.replies)
    end
  end

  describe "get_comment!/1" do
    setup [:create_drop_setup]

    test "returns the comment with given id", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)

      fetched_comment = Comments.get_comment!(comment.id)

      assert fetched_comment.id == comment.id
      assert fetched_comment.body == comment.body
    end

    test "preloads user", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)

      fetched_comment = Comments.get_comment!(comment.id)

      assert Ecto.assoc_loaded?(fetched_comment.user)
    end

    test "raises Ecto.NoResultsError for non-existent comment" do
      non_existent_id = Ecto.UUID.generate()

      assert_raise Ecto.NoResultsError, fn ->
        Comments.get_comment!(non_existent_id)
      end
    end
  end

  describe "count_drop_comments/1" do
    setup [:create_drop_setup]

    test "returns 0 for drop with no comments", %{drop: drop} do
      assert Comments.count_drop_comments(drop.id) == 0
    end

    test "returns correct count for drop with comments", %{
      drop: drop,
      user: user
    } do
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

    test "includes replies in the total count", %{drop: drop, user: user} do
      parent_comment = comment_fixture(drop, user)
      comment_fixture(drop, user, parent_comment)

      assert Comments.count_drop_comments(drop.id) == 2
    end
  end

  describe "count_user_comments/1" do
    test "counts the user's comments and replies, not other users' or deleted Drops'" do
      author = user_fixture()
      other = user_fixture()
      drop = drop_fixture(%Drop{}, author)
      doomed = drop_fixture(%Drop{}, author)

      parent = comment_fixture(drop, other, nil)
      comment_fixture(drop, other, parent)
      comment_fixture(drop, author, nil)
      comment_fixture(doomed, other, nil)
      Repo.delete!(doomed)

      assert Comments.count_user_comments(other.id) == 2
      assert Comments.count_user_comments(author.id) == 1
      assert Comments.count_user_comments(Ecto.UUID.generate()) == 0
    end
  end

  describe "count_drop_top_level_comments/1" do
    setup [:create_drop_setup]

    test "excludes replies in the total count", %{drop: drop, user: user} do
      parent_comment = comment_fixture(drop, user)
      _reply = comment_fixture(drop, user, parent_comment)

      assert Comments.count_drop_top_level_comments(drop.id) == 1
    end
  end

  describe "create_comment/4" do
    setup [:create_drop_setup]

    test "creates a comment with valid data", %{drop: drop, user: user} do
      attrs = %{body: "**some** body"}

      assert {:ok, %Comment{} = comment} = Comments.create_comment(drop, user, nil, attrs)
      assert comment.body == "**some** body"
      assert comment.drop_id == drop.id
      assert comment.user_id == user.id
      assert is_nil(comment.parent_id)
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

    test "preloads associations in returned comment", %{drop: drop, user: user} do
      attrs = %{body: "Test comment"}

      assert {:ok, comment} = Comments.create_comment(drop, user, nil, attrs)

      assert Ecto.assoc_loaded?(comment.user)
      assert Ecto.assoc_loaded?(comment.drop)
    end

    test "fails when a user tries to create a reply to a reply", %{drop: drop, user: user} do
      attrs = %{body: "Test comment"}

      parent_comment = comment_fixture(drop, user)
      reply_comment = comment_fixture(drop, user, parent_comment)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Comments.create_comment(drop, user, reply_comment, attrs)

      assert "replies cannot have replies" in errors_on(changeset).parent_id
    end
  end

  describe "edit_comment/4" do
    setup [:create_drop_setup]

    test "saves the body and sets edited_at for the author on the drop", %{
      drop: drop,
      user: user
    } do
      comment = comment_fixture(drop, user)
      assert is_nil(comment.edited_at)

      assert {:ok, %Comment{} = edited} =
               Comments.edit_comment(user, drop, comment.id, %{body: "some updated body"})

      assert edited.body == "some updated body"
      assert edited.id == comment.id
      assert %DateTime{} = edited.edited_at
      assert Comments.get_comment!(comment.id).body == "some updated body"
    end

    test "ignores a client-supplied edited_at", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)

      assert {:ok, edited} =
               Comments.edit_comment(user, drop, comment.id, %{
                 "body" => "changed",
                 "edited_at" => "2000-01-01T00:00:00Z"
               })

      assert DateTime.compare(edited.edited_at, ~U[2001-01-01 00:00:00Z]) == :gt
    end

    test "returns error changeset with invalid data", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)

      assert {:error, %Ecto.Changeset{}} =
               Comments.edit_comment(user, drop, comment.id, @invalid_attrs)

      original_comment = Comments.get_comment!(comment.id)
      assert comment.body == original_comment.body
      assert is_nil(original_comment.edited_at)
    end

    test "validates body length on edit", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)
      long_body = String.duplicate("a", 1001)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Comments.edit_comment(user, drop, comment.id, %{body: long_body})

      assert "should be at most 1000 character(s)" in errors_on(changeset).body
    end

    test "does not edit another author's comment", %{drop: drop, user: user} do
      other = user_fixture()
      comment = comment_fixture(drop, other)

      assert {:error, :not_found} =
               Comments.edit_comment(user, drop, comment.id, %{body: "forged"})

      assert Comments.get_comment!(comment.id).body == comment.body
      assert is_nil(Comments.get_comment!(comment.id).edited_at)
    end

    test "does not edit a comment of another drop", %{drop: drop, user: user} do
      other_drop = drop_fixture(%Drop{}, user)
      comment = comment_fixture(other_drop, user)

      assert {:error, :not_found} =
               Comments.edit_comment(user, drop, comment.id, %{body: "forged"})

      assert Comments.get_comment!(comment.id).body == comment.body
      assert is_nil(Comments.get_comment!(comment.id).edited_at)
    end

    test "returns not found for unknown, malformed and nil ids", %{drop: drop, user: user} do
      attrs = %{body: "forged"}

      assert {:error, :not_found} = Comments.edit_comment(user, drop, Ecto.UUID.generate(), attrs)
      assert {:error, :not_found} = Comments.edit_comment(user, drop, "not-a-uuid", attrs)
      assert {:error, :not_found} = Comments.edit_comment(user, drop, nil, attrs)
    end
  end

  describe "create_comment/4 parent scope" do
    setup [:create_drop_setup]

    test "refuses a parent comment of another drop", %{drop: drop, user: user} do
      other_drop = drop_fixture(%Drop{}, user)
      foreign_parent = comment_fixture(other_drop, user)
      count = Comments.count_drop_comments(drop.id)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Comments.create_comment(drop, user, foreign_parent, %{body: "misplaced"})

      assert "must belong to the same drop" in errors_on(changeset).parent_id
      assert Comments.count_drop_comments(drop.id) == count
      assert Comments.count_drop_comments(other_drop.id) == 1
    end

    test "still accepts a top-level parent of the same drop", %{drop: drop, user: user} do
      parent = comment_fixture(drop, user)

      assert {:ok, %Comment{parent_id: parent_id}} =
               Comments.create_comment(drop, user, parent, %{body: "proper reply"})

      assert parent_id == parent.id
    end
  end

  describe "delete_comment/3" do
    setup [:create_drop_setup]

    test "permanently deletes the user's comment on the drop", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)
      assert {:ok, %{id: id}} = Comments.delete_comment(user, drop, comment.id)
      assert id == comment.id

      assert_raise Ecto.NoResultsError, fn ->
        Comments.get_comment!(comment.id)
      end
    end

    test "deleted comment is excluded from count", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)
      assert Comments.count_drop_comments(drop.id) == 1
      assert {:ok, _comment} = Comments.delete_comment(user, drop, comment.id)
      assert Comments.count_drop_comments(drop.id) == 0
    end

    test "deleting a top-level comment removes its replies", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)
      reply = comment_fixture(drop, user, comment)

      assert {:ok, _comment} = Comments.delete_comment(user, drop, comment.id)
      assert Comments.count_drop_comments(drop.id) == 0
      assert_raise Ecto.NoResultsError, fn -> Comments.get_comment!(reply.id) end
    end

    test "deleting a reply keeps its parent", %{drop: drop, user: user} do
      comment = comment_fixture(drop, user)
      reply = comment_fixture(drop, user, comment)

      assert {:ok, _comment} = Comments.delete_comment(user, drop, reply.id)
      assert Comments.get_comment!(comment.id)
      assert Comments.count_drop_comments(drop.id) == 1
    end

    test "does not delete another author's comment", %{drop: drop, user: user} do
      other = user_fixture()
      comment = comment_fixture(drop, user)

      assert {:error, :not_found} = Comments.delete_comment(other, drop, comment.id)
      assert Comments.get_comment!(comment.id)
    end

    test "does not delete a comment of another drop", %{drop: drop, user: user} do
      other_drop = drop_fixture(%Drop{}, user)
      comment = comment_fixture(other_drop, user)

      assert {:error, :not_found} = Comments.delete_comment(user, drop, comment.id)
      assert Comments.get_comment!(comment.id)
    end

    test "returns not found for unknown or malformed ids", %{drop: drop, user: user} do
      assert {:error, :not_found} = Comments.delete_comment(user, drop, Ecto.UUID.generate())
      assert {:error, :not_found} = Comments.delete_comment(user, drop, "not-a-uuid")
    end
  end

  describe "change_comment/2" do
    setup [:create_drop_setup]

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
end
