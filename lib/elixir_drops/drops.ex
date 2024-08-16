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
  @type short_unique_string :: String.t()
  @type user :: User.t()
  @type user_id :: Ecto.UUID.t()

  @short_unique_string_allowed_chars "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  @topic inspect(__MODULE__)

  @doc """
  Subscribes to drops events.

  ## Examples

    iex> subscribe
    :ok

  """
  @spec subscribe() :: :ok
  def subscribe do
    Phoenix.PubSub.subscribe(ElixirDrops.PubSub, @topic)
  end

  @doc """
  Returns a list of drops filtered by the given filters with cursor data.

   ## Examples

      iex> list_drops(%{user_id: 1234})
      [%Drop{}, ...]

      iex> list_drops(%{older_than: %Drop{}})
      [%Drop{}, ...]

      iex> list_drops(%{newer_than: %Drop{}})
      [%Drop{}, ...]

  """
  @spec list_drops(filters(), limit()) :: [drop()]
  def list_drops(filters \\ %{}, limit \\ 10) do
    filter_query = apply_filters()

    drop_query()
    |> where(^filter_query.(filters))
    |> order_by([d], {:desc, d.inserted_at})
    |> limit(^limit)
    |> preload([:user])
    |> Repo.all()
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

  defp apply_filter({:older_than, drop}, dynamic) do
    dynamic([drop: drop], ^dynamic and drop.inserted_at < ^drop.inserted_at)
  end

  defp apply_filter({:newer_than, drop}, dynamic) do
    dynamic([drop: drop], ^dynamic and drop.inserted_at > ^drop.inserted_at)
  end

  defp apply_filter(_other, dynamic), do: dynamic

  @doc """
  Gets a single drop.

  Returns nil if the Drop does not exist.

  ## Examples

      iex> get_drop(123)
      %Drop{}

      iex> get_drop(456)
      nil

  """
  @spec get_drop(drop_id()) :: drop() | nil
  def get_drop(drop_id) do
    Drop
    |> where([drop], drop.id == ^drop_id)
    |> preload([:user])
    |> Repo.one()
  end

  @doc """
  Gets a single drop by its unique string.

  Returns nil if the Drop does not exist.

  ## Examples

      iex> get_drop_by_unique_url_string("vPfoDMdY")
      %Drop{}

      iex> get_drop_by_unique_url_string("non_existent")
      nil

  """
  @spec get_drop_by_unique_url_string(short_unique_string()) :: drop() | nil
  def get_drop_by_unique_url_string(unique_url_string) do
    Drop
    |> where([d], d.unique_url_string == ^unique_url_string)
    |> preload([:user])
    |> Repo.one()
  end

  @doc """
  Creates a drop.

  ### Examples

      iex> create_drop(%Drop{}, %User{}, %{title: "drop", ...})
      {:ok, %Drop{}}

      iex> create_drop(%Drop{}, %User{}, %{title: nil})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_drop(drop(), user(), attrs()) :: {:ok, drop()} | {:error, changeset()}
  def create_drop(%Drop{} = drop, %User{} = user, attrs \\ %{}) do
    attrs = attrs_with_unique_url_string(attrs)

    drop
    |> Drop.changeset(attrs)
    |> Ecto.Changeset.put_change(:user_id, user.id)
    |> Repo.insert()
    |> process_drop()
  end

  @doc """
  Updates a drop.

  ### Examples

      iex> update_drop(%Drop{}, %User{}, %{title: "drop", ...})
      {:ok, %Drop{}}

      iex> update_drop(%Drop{}, %User{}, %{title: nil})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_drop(drop(), user(), attrs()) :: {:ok, drop()} | {:error, changeset()}
  def update_drop(%Drop{} = drop, %User{} = user, attrs \\ %{}) do
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

  @doc """
  Generates a unique string for the drop.

  ## Examples

      iex> generate_unique_url_string()
      "vPf2DMdY"
  """
  @spec generate_unique_url_string() :: short_unique_string()
  def generate_unique_url_string do
    @short_unique_string_allowed_chars
    |> String.to_charlist()
    |> Enum.shuffle()
    |> Enum.take(8)
    |> List.to_string()
  end

  defp attrs_with_unique_url_string(attrs) do
    unique_url_string = generate_unique_url_string()

    attrs
    |> Map.put(:unique_url_string, unique_url_string)
    |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)
  end

  defp process_drop({:ok, drop}) do
    drop = Repo.preload(drop, [:user])

    broadcast_drop_creation(drop)

    {:ok, drop}
  end

  defp process_drop({:error, changeset}), do: {:error, changeset}

  defp broadcast_drop_creation(drop) do
    Phoenix.PubSub.broadcast(
      ElixirDrops.PubSub,
      @topic,
      {
        __MODULE__,
        [:drop, :created],
        drop
      }
    )
  end
end
