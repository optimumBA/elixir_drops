defmodule ElixirDrops.Bookmarks do
  @moduledoc """
  Private bookmarks: one row per account and Drop, created with its save time.

  A bookmark is only ever read for its owner (their saved state and list) or as
  an aggregate count per Drop; no function returns who bookmarked a Drop.
  """

  import Ecto.Query

  alias ElixirDrops.Bookmarks.Bookmark
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Repo

  @type drop :: Drop.t()
  @type drop_id :: Ecto.UUID.t()
  @type user_id :: Ecto.UUID.t()

  @doc """
  Saves a Drop for an account. Saving an already saved Drop leaves it unchanged
  (it keeps its original save time); an unknown Drop is `{:error, :not_found}`.
  """
  @spec save_bookmark(user_id(), drop_id()) :: :ok | {:error, :not_found}
  def save_bookmark(user_id, drop_id) do
    with {:ok, drop_id} <- Ecto.UUID.cast(drop_id),
         {:ok, _bookmark} <-
           %Bookmark{}
           |> Bookmark.changeset(%{user_id: user_id, drop_id: drop_id})
           |> Repo.insert(on_conflict: :nothing, conflict_target: [:user_id, :drop_id]) do
      :ok
    else
      _unknown_drop -> {:error, :not_found}
    end
  end

  @doc """
  Removes a saved Drop for an account. Removing an unsaved Drop changes nothing.
  """
  @spec remove_bookmark(user_id(), drop_id()) :: :ok
  def remove_bookmark(user_id, drop_id) do
    case Ecto.UUID.cast(drop_id) do
      {:ok, drop_id} ->
        Bookmark
        |> where([b], b.user_id == ^user_id and b.drop_id == ^drop_id)
        |> Repo.delete_all()

        :ok

      :error ->
        :ok
    end
  end

  @doc """
  Whether the account has saved the Drop.
  """
  @spec bookmarked?(user_id() | nil, drop_id()) :: boolean()
  def bookmarked?(nil, _drop_id), do: false

  def bookmarked?(user_id, drop_id) do
    Bookmark
    |> where([b], b.user_id == ^user_id and b.drop_id == ^drop_id)
    |> Repo.exists?()
  end

  @doc """
  The aggregate number of bookmarks of a Drop.
  """
  @spec count_drop_bookmarks(drop_id()) :: non_neg_integer()
  def count_drop_bookmarks(drop_id) do
    Bookmark
    |> where([b], b.drop_id == ^drop_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Sets `bookmarked` on every Drop in one query: whether the account has saved it.
  A signed-out viewer (`nil`) has saved nothing.
  """
  @spec maybe_mark_bookmarked([drop()], user_id() | nil) :: [drop()]
  def maybe_mark_bookmarked(drops, nil), do: drops
  def maybe_mark_bookmarked([], _user_id), do: []

  def maybe_mark_bookmarked(drops, user_id) do
    ids = Enum.map(drops, & &1.id)

    saved =
      Bookmark
      |> where([b], b.user_id == ^user_id and b.drop_id in ^ids)
      |> select([b], b.drop_id)
      |> Repo.all()
      |> MapSet.new()

    Enum.map(drops, &%{&1 | bookmarked: MapSet.member?(saved, &1.id)})
  end

  @doc """
  Sets `bookmarked` on a single Drop (or passes `nil` through).
  """
  @spec mark_bookmarked_drop(drop() | nil, user_id() | nil) :: drop() | nil
  def mark_bookmarked_drop(nil, _user_id), do: nil

  def mark_bookmarked_drop(%Drop{} = drop, user_id) do
    [marked] = maybe_mark_bookmarked([drop], user_id)
    marked
  end
end
