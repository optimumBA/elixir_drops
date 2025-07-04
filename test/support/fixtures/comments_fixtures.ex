defmodule ElixirDrops.CommentsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ElixirDrops.Comments` context.
  """

  alias ElixirDrops.Comments

  @doc """
  Generate a comment.
  """
  @spec comment_fixture(map()) :: Comments.Comment.t()
  def comment_fixture(attrs \\ %{}) do
    user = Map.get(attrs, :user) || ElixirDrops.AccountsFixtures.user_fixture()

    drop =
      Map.get(attrs, :drop) ||
        ElixirDrops.DropsFixtures.drop_fixture(%ElixirDrops.Drops.Drop{}, user)

    {:ok, comment} =
      attrs
      |> Map.delete(:user)
      |> Map.delete(:drop)
      |> Enum.into(%{
        body: "some body",
        drop_id: drop.id,
        user_id: user.id
      })
      |> Comments.create_comment()

    comment
  end

  @doc """
  Generate a reply comment.
  """
  @spec reply_fixture(Comments.Comment.t(), map()) :: Comments.Comment.t()
  def reply_fixture(parent_comment, attrs \\ %{}) do
    user = ElixirDrops.AccountsFixtures.user_fixture(%{github_id: :rand.uniform(1_000_000)})

    {:ok, reply} =
      attrs
      |> Enum.into(%{
        body: "some reply",
        drop_id: parent_comment.drop_id,
        parent_id: parent_comment.id,
        user_id: user.id
      })
      |> Comments.create_comment()

    reply
  end
end
