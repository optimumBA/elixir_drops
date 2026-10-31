defmodule ElixirDrops.CommentsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ElixirDrops.Comments` context.
  """

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Comments
  alias ElixirDrops.Comments.Comment
  alias ElixirDrops.Drops.Drop

  @type attrs :: map()
  @type comment :: Comment.t()
  @type drop :: Drop.t()
  @type user :: User.t()

  @doc """
  Generate a comment.
  """

  @spec comment_fixture(drop(), user(), comment() | nil, attrs()) ::
          comment()
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
