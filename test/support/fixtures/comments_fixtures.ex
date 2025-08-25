defmodule ElixirDrops.CommentsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ElixirDrops.Comments` context.
  """

  alias ElixirDrops.Comments
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Accounts.User

  @doc """
  Generate a comment.
  """
  @spec comment_fixture(Drop.t(), User.t(), Comment.t() | nil, map()) :: Comments.Comment.t()
  def comment_fixture(%Drop{} = drop, %User{} = user, parent \\ nil, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        body: "some body"
      })

    {:ok, comment} =
      Comments.create_comment(drop, user, parent, attrs)

    comment
  end
end
