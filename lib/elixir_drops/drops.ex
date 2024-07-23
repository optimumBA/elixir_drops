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
  @type limit :: integer()
  @type user :: User.t()
  @type user_id :: Ecto.UUID.t()

  @doc """
  Returns the list of drops.

  ## Examples

      iex> list_drops()
      [%Drop{}, ...]

  """
  @spec list_drops(limit()) :: [drop()] | []
  def list_drops(limit \\ 10) do
    Drop
    |> order_by([d], {:desc, d.inserted_at})
    |> limit(^limit)
    |> preload([:user])
    |> Repo.all()
  end

  @doc """
  Returns the list of drops newer than a given drop.

  ## Examples

      iex> list_newer_drops()
      [%Drop{}, ...]

  """
  @spec list_newer_drops(drop(), limit()) :: [drop()]
  def list_newer_drops(drop, limit \\ 10) do
    Drop
    |> where([d], d.inserted_at > ^drop.inserted_at)
    |> order_by([d], {:desc, d.inserted_at})
    |> limit(^limit)
    |> preload([:user])
    |> Repo.all()
  end

  @doc """
  Returns the list of drops older than a given drop.

  ## Examples

      iex> list_older_drops()
      [%Drop{}, ...]

  """
  @spec list_older_drops(drop(), limit()) :: [drop()]
  def list_older_drops(drop, limit \\ 10) do
    Drop
    |> where([d], d.inserted_at < ^drop.inserted_at)
    |> order_by([d], {:desc, d.inserted_at})
    |> limit(^limit)
    |> preload([:user])
    |> Repo.all()
  end

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
    |> where([d], d.id == ^drop_id)
    |> preload([:user])
    |> Repo.one()
  end

  @doc """
  Returns the list of drops belonging to a user.

  ## Examples

      iex> get_user_drops()
      [%Drop{}, ...]

  """
  @spec get_user_drops(user_id()) :: [drop()]
  def get_user_drops(user_id) do
    Drop
    |> where([d], d.user_id == ^user_id)
    |> preload([:user])
    |> Repo.all()
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
