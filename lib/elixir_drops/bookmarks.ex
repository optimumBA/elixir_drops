defmodule ElixirDrops.Bookmarks do
  @moduledoc """
  The Drops context.
  """

  import Ecto.Query

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Bookmarks.Bookmark
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Repo

  @type attrs :: map()
  @type bookmark :: Bookmark.t()
  @type changeset :: Ecto.Changeset.t()
  @type drop :: Drop.t()
  @type drop_id :: Ecto.UUID.t()
  @type filters :: map()
  @type user :: User.t()
  @type user_id :: Ecto.UUID.t()

  @doc """
  Creates a bookmark for the given `drop_id` and `user_id`.

  Returns `{:ok, %Bookmark{}}` on success or `{:error, %Ecto.Changeset{}}` on validation errors.
  """
  @spec create_bookmark(attrs()) :: {:ok, bookmark()} | {:error, changeset()}
  def create_bookmark(attrs \\ %{}) do
    %Bookmark{}
    |> Bookmark.changeset(attrs)
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

  @spec get_bookmarks(filters(), integer()) :: [bookmark()]
  def get_bookmarks(filters, limit \\ 10) do
    case safe_list_bookmarks(filters, limit) do
      {:ok, results} -> results
      {:error, _reason} -> []
    end
  end

  defp safe_list_bookmarks(filters, limit) do
    search_filters =
      case Map.get(filters, :search) do
        nil ->
          %{}

        search_query ->
          %{search: search_query}
      end

    filters = Map.delete(filters, :search)
    filter_query = apply_filters()

    result =
      bookmark_query()
      |> where(^filter_query.(search_filters))
      |> where(^filter_query.(filters))
      |> limit(^limit)
      |> preload(drop: [:user])
      |> order_by([b], {:desc, b.inserted_at})
      |> Repo.all()

    {:ok, result}
  rescue
    DBConnection.OwnershipError ->
      # Database sandbox not ready yet - return error
      {:error, :db_ownership_error}

    DBConnection.ConnectionError ->
      # Database connection issues - return error
      {:error, :db_connection_error}
  end

  @spec get_bookmarked_drops([bookmark()]) :: [drop()]
  def get_bookmarked_drops(bookmarks) do
    Enum.map(bookmarks, & &1.drop)
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

  defp bookmark_query do
    from bookmark in Bookmark, as: :bookmark
  end

  defp apply_filters do
    fn filters ->
      Enum.reduce(filters, dynamic(true), &apply_filter/2)
    end
  end

  defp apply_filter({:older_than, bookmark}, dynamic) do
    dynamic([bookmark: bookmark], ^dynamic and bookmark.inserted_at < ^bookmark.inserted_at)
  end

  defp apply_filter({:user_id, user_id}, dynamic) do
    dynamic([bookmark: bookmark], ^dynamic and bookmark.user_id == ^user_id)
  end
end
