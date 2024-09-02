defmodule ElixirDrops.Drops do
  @moduledoc """
  The Drops context.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Drops.DropTag
  alias ElixirDrops.Drops.Tag
  alias ElixirDrops.Drops.Tag
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
  def list_drops(filters \\ %{}, limit \\ 10)

  def list_drops(%{tag: tag} = filters, limit) do
    tag
    |> drop_query_with_tags()
    |> filter_query(filters, limit)
    |> Repo.all()
  end

  def list_drops(filters, limit) do
    drop_query()
    |> filter_query(filters, limit)
    |> Repo.all()
  end

  defp drop_query do
    from drop in Drop, as: :drop
  end

  defp drop_query_with_tags(tag) do
    drop_query()
    |> join(:inner, [drop], dt in DropTag, on: drop.id == dt.drop_id)
    |> join(:inner, [_drop, drop_tag], t in Tag, on: t.id == drop_tag.tag_id)
    |> where([drop, _dt, tag], tag.name == ^tag)
  end

  defp filter_query(query, filters, limit) do
    filter_query = apply_filters()

    query
    |> where(^filter_query.(filters))
    |> order_by([d], {:desc, d.inserted_at})
    |> limit(^limit)
    |> preload([:user, :tags])
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
  Returns a list of tags matching the given name.

  ## Examples

      iex> get_tag_by_name("tag")
      [%Tag{}, ...]

      iex> get_tag_by_name("tag")
      []

  """
  @spec get_tag_by_name(String.t()) :: [Tag.t()]
  def get_tag_by_name(name) do
    name = "%#{name}%"

    query =
      from(tag in Tag,
        where: ilike(tag.name, ^name),
        select: tag
      )

    Repo.all(query)
  end

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
    |> preload([:tags, :user])
    |> Repo.one()
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
  Creates a drop.

  ### Examples

      iex> create_drop(%Drop{}, %User{}, %{title: "drop", ...})
      {:ok, %Drop{}}

      iex> create_drop(%Drop{}, %User{}, %{title: nil})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_drop(drop(), user(), attrs()) :: {:ok, drop()} | {:error, changeset()}
  def create_drop(%Drop{} = drop, %User{} = user, attrs \\ %{}) do
    case create_or_update_drop(drop, user, attrs) do
      {:ok, drop} ->
        :ok = broadcast_drop_creation(drop)

        {:ok, drop}

      {:error, changeset} ->
        {:error, changeset}
    end
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
  def update_drop(%Drop{} = drop, %User{} = user, attrs \\ %{}),
    do: create_or_update_drop(drop, user, attrs)

  defp create_or_update_drop(drop, user, attrs) do
    tags = attrs[:tags] || attrs["tags"] || []

    Multi.new()
    |> Multi.run(:tags, fn _repo, changes ->
      insert_and_get_all_tags(changes, tags)
    end)
    |> Multi.run(:drop, fn _repo, changes ->
      insert_or_update_drop(changes, drop, user, attrs)
    end)
    |> Repo.transaction()
    |> process_result()
  end

  defp process_result({:ok, %{drop: drop}}) do
    drop = Repo.preload(drop, [:tags, :user])

    {:ok, drop}
  end

  defp process_result({:error, _name, changeset, _changes}), do: {:error, changeset}

  defp insert_and_get_all_tags(_changes, tags) do
    case tags do
      [] ->
        {:ok, []}

      names ->
        timestamp = now()
        maps = name_map(names, timestamp)

        Repo.insert_all(Tag, maps, on_conflict: :nothing)

        {:ok, Repo.all(from t in Tag, where: t.name in ^names)}
    end
  end

  defp insert_or_update_drop(%{tags: tags}, drop, user, attrs) do
    drop
    |> Drop.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:tags, tags)
    |> Ecto.Changeset.put_assoc(:user, user)
    |> Ecto.Changeset.validate_length(:tags,
      min: 2,
      max: 10,
      message: "Should have at least 2 drops and at most 10 tags"
    )
    |> Repo.insert_or_update()
  end

  defp now do
    now = NaiveDateTime.utc_now()

    NaiveDateTime.truncate(now, :second)
  end

  defp name_map(names, timestamp) do
    Enum.map(
      names,
      &%{
        name: &1,
        inserted_at: timestamp,
        updated_at: timestamp
      }
    )
  end

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
