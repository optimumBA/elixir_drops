defmodule ElixirDrops.Comments do
  @moduledoc """
  The Comments context.
  """

  import Ecto.Query, warn: false

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Comments.Comment
  alias ElixirDrops.Comments.CommentsBroadcast
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Repo

  @type attrs :: map()
  @type changeset :: Ecto.Changeset.t()
  @type comment :: Comment.t()
  @type comment_id :: Ecto.UUID.t()
  @type drop :: Drop.t()
  @type drop_id :: Ecto.UUID.t()
  @type parent_comment :: Comment.t() | nil
  @type user :: User.t()
  @type user_id :: Ecto.UUID.t()

  @preload_list [
    :user,
    parent: [:user],
    replies: [
      :user,
      parent: [:user],
      replies: [
        :user,
        parent: [:user],
        replies: [
          :user,
          parent: [:user],
          replies: [
            :user,
            parent: [:user]
          ]
        ]
      ]
    ]
  ]

  @doc """
  Subscribe to comment events for a drop.

  ## Examples

      iex> subscribe_to_drop_comments("550e8400-e29b-41d4-a716-446655440000")
      :ok

  """
  @spec subscribe_to_drop_comments(drop_id) :: :ok
  def subscribe_to_drop_comments(drop_id) do
    CommentsBroadcast.subscribe_to_drop(drop_id)
  end

  @doc """
  Lists comments for a drop with pagination.

  ## Examples

      iex> list_drop_comments("550e8400-e29b-41d4-a716-446655440000")
      [%Comment{}, ...]

      iex> list_drop_comments("550e8400-e29b-41d4-a716-446655440000", limit: 5, offset: 10)
      [%Comment{}, ...]

  """
  @spec list_drop_comments(drop_id, keyword()) :: [comment()]
  def list_drop_comments(drop_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    offset = Keyword.get(opts, :offset, 0)

    Comment
    |> where([c], c.drop_id == ^drop_id and is_nil(c.parent_id))
    |> order_by([c], desc: c.inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> preload(^@preload_list)
    |> Repo.all()
  end

  @doc """
  Gets a single comment.

  Raises `Ecto.NoResultsError` if the comment does not exist.

  ## Examples

      iex> get_comment!("550e8400-e29b-41d4-a716-446655440000")
      %Comment{}

      iex> get_comment!("non_existent_id")
      ** (Ecto.NoResultsError)

  """
  @spec get_comment!(comment_id) :: comment()
  def get_comment!(id) do
    comment = Repo.get!(Comment, id)
    Repo.preload(comment, @preload_list)
  end

  @doc """
  Counts comments for a drop.

  ## Examples

      iex> count_drop_comments("550e8400-e29b-41d4-a716-446655440000")
      5

  """
  @spec count_drop_comments(drop_id) :: non_neg_integer()
  def count_drop_comments(drop_id) do
    Comment
    |> where([c], c.drop_id == ^drop_id and is_nil(c.deleted_at))
    |> Repo.aggregate(:count)
  end

  @spec count_drop_top_level_comments(drop_id) :: non_neg_integer()
  def count_drop_top_level_comments(drop_id) do
    Comment
    |> where([c], c.drop_id == ^drop_id and is_nil(c.deleted_at) and is_nil(c.parent_id))
    |> Repo.aggregate(:count)
  end

  @doc """
  Creates a comment.

  ## Examples

      iex> create_comment(%Drop{}, %User{}, nil, %{body: "This is a great drop!"})
      {:ok, %Comment{}}

      iex> create_comment(%Drop{}, %User{}, %Comment{}, %{body: "This is a reply"})
      {:ok, %Comment{}}

      iex> create_comment(%Drop{}, %User{}, nil, %{body: nil})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_comment(drop(), user(), parent_comment() | nil, attrs()) ::
          {:ok, comment()} | {:error, changeset()}
  def create_comment(%Drop{} = drop, %User{} = user, parent, attrs) do
    %Comment{}
    |> create_comment_changeset(drop, user, parent, attrs)
    |> Repo.insert()
    |> broadcast_comment_event(:created)
  end

  defp create_comment_changeset(comment, drop, user, parent, attrs) do
    comment
    |> Comment.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:drop, drop)
    |> Ecto.Changeset.put_assoc(:user, user)
    |> verify_parent_comment(parent)
  end

  defp verify_parent_comment(changeset, nil), do: changeset

  defp verify_parent_comment(changeset, parent) do
    case is_nil(parent.parent_id) do
      true ->
        Ecto.Changeset.put_assoc(changeset, :parent, parent)

      false ->
        Ecto.Changeset.add_error(changeset, :parent_id, "replies cannot have replies")
    end
  end

  @doc """
  Updates a comment.

  ## Examples

      iex> update_comment(%Comment{}, %{content: "Updated content"})
      {:ok, %Comment{}}

      iex> update_comment(%Comment{}, %{content: nil})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_comment(comment(), attrs()) ::
          {:ok, comment()} | {:error, changeset()}
  def update_comment(%Comment{} = comment, attrs) do
    comment
    |> Comment.changeset(attrs)
    |> Repo.update()
    |> broadcast_comment_event(:updated)
  end

  @doc """
  Soft deletes a comment.

  ## Examples

      iex> delete_comment(%Comment{})
      {:ok, %Comment{deleted_at: ~U[2023-01-01 00:00:00Z]}}

      iex> delete_comment(%Comment{})
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_comment(comment()) :: {:ok, comment()} | {:error, changeset()}
  def delete_comment(%Comment{} = comment) do
    comment
    |> Ecto.Changeset.change(deleted_at: DateTime.utc_now())
    |> Repo.update()
    |> broadcast_comment_event(:deleted)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking comment changes.

  ## Examples

      iex> change_comment(%Comment{})
      %Ecto.Changeset{data: %Comment{}}

  """
  @spec change_comment(comment(), attrs()) :: changeset()
  def change_comment(%Comment{} = comment, attrs \\ %{}) do
    Comment.changeset(comment, attrs)
  end

  @doc """
  Checks if a user can edit a comment.

  ## Examples

      iex> can_edit_comment?(%Comment{user_id: "123"}, "123")
      true

  """
  @spec can_edit_comment?(comment(), user_id) :: boolean()
  def can_edit_comment?(%Comment{user_id: user_id}, current_user_id) do
    user_id == current_user_id
  end

  @doc """
  Checks if a user can delete a comment.

  ## Examples

      iex> can_delete_comment?(%Comment{user_id: "123"}, "123")
      true

  """
  @spec can_delete_comment?(Comment.t(), String.t()) :: boolean()
  def can_delete_comment?(%Comment{user_id: user_id}, current_user_id) do
    user_id == current_user_id
  end

  defp broadcast_comment_event({:ok, comment} = result, event) do
    comment = Repo.preload(comment, @preload_list)
    CommentsBroadcast.broadcast_comment_event(comment, event)
    result
  end

  defp broadcast_comment_event(error, _event), do: error
end
