defmodule ElixirDrops.Comments.CommentTest do
  use ElixirDrops.DataCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Comments.Comment
  alias ElixirDrops.Drops.Drop

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Comment.changeset(%Comment{}, %{})

      assert %{
               body: ["can't be blank"],
               drop_id: ["can't be blank"],
               user_id: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates body length" do
      user = user_fixture()
      drop = drop_fixture(%Drop{}, user)

      # Test minimum length
      min_changeset =
        Comment.changeset(%Comment{}, %{
          body: "",
          drop_id: drop.id,
          user_id: user.id
        })

      assert "can't be blank" in errors_on(min_changeset).body

      # Test maximum length
      long_body = String.duplicate("a", 1001)

      max_changeset =
        Comment.changeset(%Comment{}, %{
          body: long_body,
          drop_id: drop.id,
          user_id: user.id
        })

      assert "should be at most 1000 character(s)" in errors_on(max_changeset).body
    end

    test "generates body_html from body" do
      user = user_fixture()
      drop = drop_fixture(%Drop{}, user)

      changeset =
        Comment.changeset(%Comment{}, %{
          body: "**bold** and *italic*",
          drop_id: drop.id,
          user_id: user.id
        })

      assert changeset.valid?
      body_html = Ecto.Changeset.get_change(changeset, :body_html)
      assert body_html =~ "<strong>bold</strong>"
      assert body_html =~ "<em>italic</em>"
    end
  end

  describe "edit_changeset/2" do
    test "validates body and sets edited_at" do
      comment = %Comment{body: "original"}

      changeset = Comment.edit_changeset(comment, %{body: "updated"})

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :body) == "updated"
      assert Ecto.Changeset.get_change(changeset, :edited_at) != nil
    end

    test "validates body length in edit" do
      comment = %Comment{body: "original"}
      long_body = String.duplicate("a", 1001)

      changeset = Comment.edit_changeset(comment, %{body: long_body})

      refute changeset.valid?
      assert "should be at most 1000 character(s)" in errors_on(changeset).body
    end
  end
end
