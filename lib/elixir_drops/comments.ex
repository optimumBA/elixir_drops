defmodule ElixirDrops.Comments do
  @moduledoc """
  The Comments context.
  """

  import Ecto.Query

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Comments.Comment
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Repo

  @type attrs :: map()
  @type changeset :: Ecto.Changeset.t()
  @type comment :: Comment.t()
  @type comment_id :: Ecto.UUID.t()
  @type drop :: Drop.t()
  @type drop_id :: Ecto.UUID.t()
  @type options :: keyword()
  @type parent_comment :: Comment.t() | nil
  @type user :: User.t()

  @doc """
  Lists comments for a drop with pagination.

  ## Examples

      iex> list_drop_comments("550e8400-e29b-41d4-a716-446655440000")
      [%Comment{}, ...]

      iex> list_drop_comments("550e8400-e29b-41d4-a716-446655440000", limit: 5, offset: 10)
      [%Comment{}, ...]

  """
  @spec list_drop_comments(drop_id(), options()) :: [comment()]
  def list_drop_comments(drop_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    offset = Keyword.get(opts, :offset, 0)

    Comment
    |> where([c], c.drop_id == ^drop_id and is_nil(c.parent_id))
    |> order_by([c], desc: c.inserted_at, desc: c.id)
    |> limit(^limit)
    |> offset(^offset)
    |> preload(^preload_list())
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
  @spec get_comment!(comment_id()) :: comment()
  def get_comment!(id) do
    Comment
    |> Repo.get!(id)
    |> Repo.preload(preload_list())
  end

  @doc """
  Counts comments for a drop.

  ## Examples

      iex> count_drop_comments("550e8400-e29b-41d4-a716-446655440000")
      5

  """
  @spec count_drop_comments(drop_id()) :: non_neg_integer()
  def count_drop_comments(drop_id) do
    Comment
    |> where([c], c.drop_id == ^drop_id)
    |> Repo.aggregate(:count)
  end

  @spec count_drop_top_level_comments(drop_id()) :: non_neg_integer()
  def count_drop_top_level_comments(drop_id) do
    Comment
    |> where([c], c.drop_id == ^drop_id and is_nil(c.parent_id))
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
  end

  @doc """
  Deletes a comment written by `user` on `drop`.

  The comment ID is matched together with both the author and the Drop, so any
  other ID (another author's comment, a comment of another Drop, an unknown or
  malformed ID) deletes nothing and returns `{:error, :not_found}`. Replies of a
  deleted top-level comment are removed by the database cascade.

  ## Examples

      iex> delete_comment(%User{}, %Drop{}, comment_id)
      {:ok, %Comment{}}

      iex> delete_comment(%User{}, %Drop{}, other_comment_id)
      {:error, :not_found}

  """
  @spec delete_comment(user(), drop(), comment_id()) :: {:ok, comment()} | {:error, :not_found}
  def delete_comment(%User{id: user_id}, %Drop{id: drop_id}, comment_id) do
    case Ecto.UUID.cast(comment_id) do
      {:ok, comment_id} ->
        Comment
        |> where([c], c.id == ^comment_id and c.user_id == ^user_id and c.drop_id == ^drop_id)
        |> delete_scoped_comment()

      :error ->
        {:error, :not_found}
    end
  end

  defp delete_scoped_comment(scope) do
    comment =
      scope
      |> preload(^preload_list())
      |> Repo.one()

    case comment && Repo.delete_all(scope) do
      {1, _rows} -> {:ok, comment}
      _no_match -> {:error, :not_found}
    end
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

  defp create_comment_changeset(comment, drop, user, parent, attrs) do
    comment
    |> Comment.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:drop, drop)
    |> Ecto.Changeset.put_assoc(:user, user)
    |> maybe_verify_parent_comment(parent)
  end

  defp maybe_verify_parent_comment(changeset, nil), do: changeset

  defp maybe_verify_parent_comment(changeset, %{parent_id: nil} = parent),
    do: Ecto.Changeset.put_assoc(changeset, :parent, parent)

  defp maybe_verify_parent_comment(changeset, _parent),
    do: Ecto.Changeset.add_error(changeset, :parent_id, "replies cannot have replies")

  defp preload_list do
    [
      :user,
      parent: [:user],
      replies:
        {replies_query(),
         [
           :user,
           parent: [:user]
         ]}
    ]
  end

  defp replies_query do
    from r in Comment, order_by: [desc: r.inserted_at]
  end
end
