defmodule ElixirDrops.Comments do
  @moduledoc """
  The Comments context.
  """

  import Ecto.Query, warn: false

  alias ElixirDrops.Comments.Comment
  alias ElixirDrops.Comments.CommentsBroadcast
  alias ElixirDrops.Repo

  @doc """
  Subscribe to comment events for a drop.
  """
  @spec subscribe_to_drop_comments(String.t()) :: :ok
  def subscribe_to_drop_comments(drop_id) do
    CommentsBroadcast.subscribe_to_drop(drop_id)
  end

  @doc """
  Lists comments for a drop with pagination.
  """
  @spec list_drop_comments(String.t(), keyword()) :: [Comment.t()]
  def list_drop_comments(drop_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    offset = Keyword.get(opts, :offset, 0)

    Comment
    |> where([c], c.drop_id == ^drop_id)
    |> where([c], is_nil(c.parent_id))
    |> order_by([c], desc: c.inserted_at, desc: c.id)
    |> limit(^limit)
    |> offset(^offset)
    |> preload([:user, replies: [:user]])
    |> Repo.all()
  end

  @doc """
  Gets a single comment.
  """
  @spec get_comment!(String.t()) :: Comment.t()
  def get_comment!(id) do
    comment = Repo.get!(Comment, id)
    Repo.preload(comment, [:user, :drop])
  end

  @doc """
  Counts comments for a drop.
  """
  @spec count_drop_comments(String.t()) :: integer()
  def count_drop_comments(drop_id) do
    Comment
    |> where([c], c.drop_id == ^drop_id)
    |> where([c], is_nil(c.deleted_at))
    |> Repo.aggregate(:count)
  end

  @doc """
  Creates a comment.
  """
  @spec create_comment(map()) :: {:ok, Comment.t()} | {:error, Ecto.Changeset.t()}
  def create_comment(attrs \\ %{}) do
    %Comment{}
    |> Comment.changeset(attrs)
    |> Repo.insert()
    |> broadcast_comment_event(:created)
  end

  @doc """
  Updates a comment.
  """
  @spec update_comment(Comment.t(), map()) :: {:ok, Comment.t()} | {:error, Ecto.Changeset.t()}
  def update_comment(%Comment{} = comment, attrs) do
    comment
    |> Comment.edit_changeset(attrs)
    |> Repo.update()
    |> broadcast_comment_event(:updated)
  end

  @doc """
  Soft deletes a comment.
  """
  @spec delete_comment(Comment.t()) :: {:ok, Comment.t()} | {:error, Ecto.Changeset.t()}
  def delete_comment(%Comment{} = comment) do
    comment
    |> Ecto.Changeset.change(deleted_at: DateTime.utc_now())
    |> Repo.update()
    |> broadcast_comment_event(:deleted)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking comment changes.
  """
  @spec change_comment(Comment.t(), map()) :: Ecto.Changeset.t()
  def change_comment(%Comment{} = comment, attrs \\ %{}) do
    Comment.changeset(comment, attrs)
  end

  @doc """
  Checks if a user can edit a comment.
  """
  @spec can_edit_comment?(Comment.t(), String.t()) :: boolean()
  def can_edit_comment?(%Comment{user_id: user_id}, current_user_id) do
    user_id == current_user_id
  end

  @doc """
  Checks if a user can delete a comment.
  """
  @spec can_delete_comment?(Comment.t(), String.t()) :: boolean()
  def can_delete_comment?(%Comment{user_id: user_id}, current_user_id) do
    user_id == current_user_id
  end

  defp broadcast_comment_event({:ok, comment} = result, event) do
    comment = Repo.preload(comment, [:user, :drop, replies: :user])
    CommentsBroadcast.broadcast_comment_event(comment, event)
    result
  end

  defp broadcast_comment_event(error, _event), do: error
end
