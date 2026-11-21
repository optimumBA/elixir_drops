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
  @type user_id :: Ecto.UUID.t()

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

  @doc """
  Counts every stored comment and reply written by a user.
  """
  @spec count_user_comments(user_id()) :: non_neg_integer()
  def count_user_comments(user_id) do
    Comment
    |> where([c], c.user_id == ^user_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Lists the stored comments and replies written by a user, newest first, in
  cursor-paged batches for the public profile activity feed.

  `:older_than` takes the last comment of the previous batch; equal timestamps
  are broken by descending id so every entry appears exactly once across
  batches. Each entry carries its Drop and, for a reply, its parent comment
  with the parent's author.

  ## Examples

      iex> list_user_comments(user_id, limit: 10)
      [%Comment{}, ...]

      iex> list_user_comments(user_id, limit: 10, older_than: last_comment)
      [%Comment{}, ...]

  """
  @spec list_user_comments(user_id(), options()) :: [comment()]
  def list_user_comments(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    Comment
    |> where([c], c.user_id == ^user_id)
    |> maybe_user_comments_cursor(Keyword.get(opts, :older_than))
    |> order_by([c], desc: c.inserted_at, desc: c.id)
    |> limit(^limit)
    |> preload([:drop, parent: [:user]])
    |> Repo.all()
  end

  defp maybe_user_comments_cursor(query, nil), do: query

  defp maybe_user_comments_cursor(query, %Comment{inserted_at: inserted_at, id: id}) do
    where(
      query,
      [c],
      c.inserted_at < ^inserted_at or (c.inserted_at == ^inserted_at and c.id < ^id)
    )
  end

  @doc """
  Fetches a user's stored comments by id, returned in the order of `ids`.

  Used to restore a previously loaded profile activity feed; ids that no
  longer exist are simply absent from the result.
  """
  @spec list_user_comments_by_ids(user_id(), [comment_id()]) :: [comment()]
  def list_user_comments_by_ids(user_id, ids) do
    positions =
      ids
      |> Enum.with_index()
      |> Map.new()

    Comment
    |> where([c], c.user_id == ^user_id and c.id in ^ids)
    |> preload([:drop, parent: [:user]])
    |> Repo.all()
    |> Enum.sort_by(&Map.fetch!(positions, &1.id))
  end

  @doc """
  Gets a single comment without preloads, or `nil` for an unknown or malformed id.
  """
  @spec get_comment(comment_id() | nil) :: comment() | nil
  def get_comment(id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} -> Repo.get(Comment, id)
      :error -> nil
    end
  end

  @doc """
  Position of a comment's top-level thread in a Drop's newest-first
  conversation: the number of top-level comments ordered before it, using the
  same `inserted_at`/id ordering as `list_drop_comments/2`. For a reply, the
  position of its parent.
  """
  @spec thread_offset(comment()) :: non_neg_integer()
  def thread_offset(%Comment{parent_id: nil} = comment), do: newer_top_level_count(comment)

  def thread_offset(%Comment{parent_id: parent_id}) do
    case Repo.get(Comment, parent_id) do
      nil -> 0
      parent -> newer_top_level_count(parent)
    end
  end

  defp newer_top_level_count(%Comment{} = comment) do
    Comment
    |> where([c], c.drop_id == ^comment.drop_id and is_nil(c.parent_id))
    |> where(
      [c],
      c.inserted_at > ^comment.inserted_at or
        (c.inserted_at == ^comment.inserted_at and c.id > ^comment.id)
    )
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
  Edits a comment written by `user` on `drop`.

  The comment ID is matched together with both the author and the Drop, so any
  other ID (another author's comment, a comment of another Drop, an unknown or
  malformed ID) changes nothing and returns `{:error, :not_found}`. On success
  the body is saved and `edited_at` is set to the current time.

  ## Examples

      iex> edit_comment(%User{}, %Drop{}, comment_id, %{"body" => "Updated"})
      {:ok, %Comment{}}

      iex> edit_comment(%User{}, %Drop{}, comment_id, %{"body" => ""})
      {:error, %Ecto.Changeset{}}

      iex> edit_comment(%User{}, %Drop{}, other_comment_id, %{"body" => "Updated"})
      {:error, :not_found}

  """
  @spec edit_comment(user(), drop(), comment_id() | nil, attrs()) ::
          {:ok, comment()} | {:error, changeset()} | {:error, :not_found}
  def edit_comment(%User{id: user_id}, %Drop{id: drop_id}, comment_id, attrs) do
    with {:ok, comment_id} <- Ecto.UUID.cast(comment_id),
         %Comment{} = comment <-
           Comment
           |> where([c], c.id == ^comment_id and c.user_id == ^user_id and c.drop_id == ^drop_id)
           |> Repo.one() do
      comment
      |> Comment.changeset(attrs)
      |> Ecto.Changeset.put_change(:edited_at, DateTime.utc_now())
      |> Repo.update()
    else
      _no_match -> {:error, :not_found}
    end
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

  defp maybe_verify_parent_comment(changeset, %{parent_id: nil, drop_id: drop_id} = parent) do
    if drop_id == Ecto.Changeset.get_field(changeset, :drop).id do
      Ecto.Changeset.put_assoc(changeset, :parent, parent)
    else
      Ecto.Changeset.add_error(changeset, :parent_id, "must belong to the same drop")
    end
  end

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
