defmodule ElixirDrops.Bookmarks do
  @moduledoc """
  The Drops context.
  """

  import Ecto.Query

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Bookmarks.Bookmark
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Repo

  require Logger

  @type attrs :: map()
  @type bookmark :: Bookmark.t()
  @type changeset :: Ecto.Changeset.t()
  @type drop :: Drop.t()
  @type drop_id :: Ecto.UUID.t()
  @type user :: User.t()
  @type user_id :: Ecto.UUID.t()

  @doc """
  Creates a bookmark for the given `drop_id` and `user_id`.

  Returns `{:ok, %Bookmark{}}` on success or `{:error, %Ecto.Changeset{}}` on validation errors.
  """
  @spec create_bookmark(drop_id(), user_id()) :: {:ok, bookmark()} | {:error, changeset()}
  def create_bookmark(drop_id, user_id) do
    %Bookmark{}
    |> Bookmark.changeset(%{drop_id: drop_id, user_id: user_id})
    |> Repo.insert()
  end

  @doc """
  Reads (fetches) a bookmark by `drop_id` and `user_id`.

  Returns `%Bookmark{}` if found, otherwise `nil`.
  """
  @spec get_bookmark(drop_id(), user_id()) :: bookmark() | nil
  def get_bookmark(drop_id, user_id) do
    Bookmark
    |> where([b], b.drop_id == ^drop_id and b.user_id == ^user_id)
    |> Repo.one()
  end

  @spec get_bookmarks_for_user(user_id()) :: [bookmark()]
  def get_bookmarks_for_user(user_id) do
    Bookmark
    |> where([b], b.user_id == ^user_id)
    |> Repo.all()
  end

  @spec drop_bookmarked?(drop_id(), user_id()) :: boolean()
  def drop_bookmarked?(drop_id, user_id) do
    case get_bookmark(drop_id, user_id) do
      nil -> false
      _bookmark -> true
    end
  end

  @doc """
  Deletes a bookmark identified by `drop_id` and `user_id`.
  Returns `{:ok, %Bookmark{}}` when deleted or `{:error, :not_found}` if no bookmark exists.
  """
  @spec delete_bookmark(bookmark()) ::
          {:ok, bookmark()} | {:error, changeset()}
  def delete_bookmark(bookmark) do
    Repo.delete(bookmark)
  end
end
