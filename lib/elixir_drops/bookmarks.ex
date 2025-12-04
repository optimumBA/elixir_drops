defmodule ElixirDrops.Bookmarks do
  @moduledoc """
  The Bookmarks context.
  """

  import Ecto.Query

  alias ElixirDrops.Bookmarks.Bookmark
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Repo
  alias ElixirDrops.TextSearchHelpers

  @type attrs :: map()
  @type bookmark :: Bookmark.t()
  @type changeset :: Ecto.Changeset.t()
  @type drop :: Drop.t()
  @type drop_id :: Ecto.UUID.t()
  @type filters :: map()
  @type user_id :: Ecto.UUID.t()

  @doc """
  Creates a bookmark.

  ## Examples

    iex> create_bookmark(%{
    ...>   drop_id: "056a0e76-2e3c-4c00-9efa-46ebb34cd19a",
    ...>   user_id: "f2b5c006-6848-427b-89c0-629c3ba8a3de"
    ...> })
    {:ok, %Bookmark{}}

  Returns `{:ok, %Bookmark{}}` on success or `{:error, %Ecto.Changeset{}}` on validation errors.
  """
  @spec create_bookmark(attrs()) :: {:ok, bookmark()} | {:error, changeset()}
  def create_bookmark(attrs \\ %{}) do
    %Bookmark{}
    |> Bookmark.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Fetches a bookmark by `drop_id` and `user_id`.

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
    search_filters =
      case Map.get(filters, :search) do
        nil ->
          %{}

        search_query ->
          %{search: search_query}
      end

    other_filters = Map.delete(filters, :search)
    filter_query = apply_filters()

    bookmark_query()
    |> where(^filter_query.(search_filters))
    |> where(^filter_query.(other_filters))
    |> limit(^limit)
    |> preload(drop: [:user])
    |> TextSearchHelpers.apply_search_ordering(filters[:search])
    |> Repo.all()
  end

  @spec delete_bookmark(bookmark()) ::
          {:ok, bookmark()} | {:error, changeset()}
  def delete_bookmark(bookmark) do
    Repo.delete(bookmark)
  end

  @spec get_bookmarked_drops([bookmark()]) :: [drop()]
  def get_bookmarked_drops(bookmarks) do
    Enum.map(bookmarks, &Map.put(&1.drop, :bookmarked?, true))
  end

  defp bookmark_query do
    from bookmark in Bookmark,
      as: :bookmark,
      join: drop in assoc(bookmark, :drop),
      as: :drop
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

  defp apply_filter({:search, query}, dynamic),
    do: TextSearchHelpers.apply_filter({:search, query}, dynamic)

  defp apply_filter({:relevance_rank, {rank, search_query}}, dynamic),
    do: TextSearchHelpers.apply_filter({:relevance_rank, {rank, search_query}}, dynamic)
end
