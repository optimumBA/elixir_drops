defmodule ElixirDrops.Drops do
  @moduledoc """
  The Drops context.
  """

  import Ecto.Query, warn: false

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Repo

  @type attrs :: map()
  @type changeset :: Ecto.Changeset.t()
  @type drop :: Drop.t()
  @type drop_id :: Ecto.UUID.t()
  @type filters :: map()
  @type limit :: integer()
  @type page :: integer()
  @type user :: User.t()
  @type user_id :: Ecto.UUID.t()

  @doc """
  Returns a list of drops filtered by the given filters with pagination metadata.

  ## Examples

      iex> list_drops(10, %{user_id: 1234})
      %{
        current_page: 1,
        entries: [%Drop{}, ...],
        total_pages: 5
      }

      iex> list_drops(10, %{older_than: %Drop{}})
      %{
        current_page: 1,
        entries: [%Drop{}, ...],
        total_pages: 5
      }

      iex> list_drops(10, %{newer_than: %Drop{}})
      %{
        current_page: 1,
        entries: [%Drop{}, ...],
        total_pages: 5
      }

  """
  @spec list_drops(limit(), filters(), page()) :: map()
  def list_drops(limit, filters \\ %{}, page \\ 1) do
    filters
    |> fetch_drops()
    |> paginate(page, limit)
  end

  defp fetch_drops(filters) do
    filter_query = apply_filters()

    drop_query()
    |> where(^filter_query.(filters))
    |> order_by([d], {:desc, d.inserted_at})
    |> preload([:user])
  end

  defp paginate(query, page, limit) do
    results =
      query
      |> limit(^limit)
      |> offset(^((page - 1) * limit))
      |> Repo.all()

    count = Repo.aggregate(query, :count)

    %{
      current_page: page,
      entries: Enum.slice(results, 0, limit),
      total_pages: if(count > 0, do: ceil(count / limit), else: 0)
    }
  end


  defp drop_query do
    from drop in Drop, as: :drop
  end

  defp apply_filters do
    fn filters ->
      Enum.reduce(filters, dynamic(true), &apply_filter/2)
    end
  end

  defp apply_filter({:user_id, user_id}, dynamic) do
    dynamic([drop: drop], ^dynamic and drop.user_id == ^user_id)
  end

  defp apply_filter(_other, dynamic), do: dynamic

  @doc """
  Gets a single drop.

  Returns nil if the Drop does not exist.

  ## Examples

      iex> get_drop(123)
      %Drop{}

      iex> get_drop(456)
      ** nil

  """
  @spec get_drop(drop_id()) :: drop() | nil
  def get_drop(drop_id) do
    Drop
    |> where([drop], drop.id == ^drop_id)
    |> preload([:user])
    |> Repo.one()
  end

  @doc """
  Creates or updates a drop .

  ## Examples

      iex> create_or_update_drop(%Drop{}, %User{}, %{title: "drop", ...})
      {:ok, %Drop{}}

      iex> create_or_update_drop(%Drop{}, %User{}, %{title: nil})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_or_update_drop(drop(), user(), attrs()) :: {:ok, drop()} | {:error, changeset()}
  def create_or_update_drop(drop, user, attrs \\ %{}) do
    drop
    |> Drop.changeset(attrs)
    |> Ecto.Changeset.put_change(:user_id, user.id)
    |> Repo.insert_or_update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking drop changes.

  ## Examples

      iex> change_drop(drop)
      %Ecto.Changeset{data: %Drop{}}

  """
  @spec change_drop(drop(), attrs()) :: changeset()
  def change_drop(%Drop{} = drop, attrs \\ %{}) do
    Drop.changeset(drop, attrs)
  end
end
