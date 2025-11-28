defmodule ElixirDrops.Drops do
  @moduledoc """
  The Drops context.
  """

  import Ecto.Query, warn: false

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Comments.Comment
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Drops.DropsBroadcast
  alias ElixirDrops.Drops.ShortIdGenerator
  alias ElixirDrops.MarkdownCache
  alias ElixirDrops.Repo

  require Logger

  @type attrs :: map()
  @type changeset :: Ecto.Changeset.t()
  @type drop :: Drop.t()
  @type drop_id :: Ecto.UUID.t()
  @type filters :: map()
  @type limit :: integer()
  @type page :: integer()
  @type short_id :: String.t()
  @type user :: User.t()
  @type user_id :: Ecto.UUID.t()

  @doc """
  Subscribes to drops events by calling DropsBroadcast.subscribe/0` function.

  ## Examples

    iex> subscribe()
    :ok

  """
  @spec subscribe() :: :ok
  def subscribe do
    DropsBroadcast.subscribe()
  end

  @doc """
  Lists all drops for markdown index generation.
  Preloads users but limits body field for performance.
  """
  @spec list_all_drops() :: [drop()]
  def list_all_drops do
    Drop
    |> from(order_by: [desc: :inserted_at])
    |> preload(:user)
    |> Repo.all()
    |> Enum.map(&truncate_body_for_index/1)
  end

  @spec truncate_body_for_index(drop()) :: drop()
  defp truncate_body_for_index(%Drop{body: body} = drop) when byte_size(body) > 500 do
    %{drop | body: binary_part(body, 0, 500)}
  end

  defp truncate_body_for_index(drop), do: drop

  @doc """
  Returns a list of drops filtered by the given filters with cursor data.

   ## Examples

      iex> list_drops(%{user_id: user_id})
      [%Drop{}, ...]

      iex> list_drops(%{older_than: %Drop{}})
      [%Drop{}, ...]

      iex> list_drops(%{newer_than: %Drop{}})
      [%Drop{}, ...]

  """
  @spec list_drops(filters(), limit()) :: [drop()]
  def list_drops(filters \\ %{}, limit \\ 10) do
    case safe_list_drops(filters, limit) do
      {:ok, results} -> results
      {:error, _reason} -> []
    end
  end

  defp safe_list_drops(filters, limit) do
    search_filters =
      case Map.get(filters, :search) do
        nil ->
          %{}

        search_query ->
          %{search: search_query}
      end

    other_filters = Map.delete(filters, :search)
    filter_query = apply_filters()

    query =
      drop_query()
      |> where(^filter_query.(search_filters))
      |> where(^filter_query.(other_filters))
      |> limit(^limit)
      |> merge_comment_count()
      |> preload([:user])

    result =
      query
      |> apply_search_ordering(filters[:search])
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

  defp drop_query do
    from drop in Drop, as: :drop
  end

  defp apply_search_ordering(query, search_query)
       when is_binary(search_query) and search_query != "" do
    query
    |> select_merge([drop: drop], %{
      relevance_rank:
        fragment(
          "ts_rank(?, websearch_to_tsquery('english', ?))",
          drop.search_vector,
          ^search_query
        )
    })
    |> order_by(
      [drop: drop],
      desc:
        fragment(
          "ts_rank(?, websearch_to_tsquery('english', ?))",
          drop.search_vector,
          ^search_query
        )
    )
  end

  defp apply_search_ordering(query, _no_search) do
    order_by(query, [d], {:desc, d.inserted_at})
  end

  defp apply_filters do
    fn filters ->
      Enum.reduce(filters, dynamic(true), &apply_filter/2)
    end
  end

  defp apply_filter({:drop_id, drop_id}, dynamic) do
    dynamic([drop: drop], ^dynamic and drop.id == ^drop_id)
  end

  defp apply_filter({:newer_than, drop}, dynamic) do
    dynamic([drop: drop], ^dynamic and drop.inserted_at > ^drop.inserted_at)
  end

  defp apply_filter({:older_than, drop}, dynamic) do
    dynamic([drop: drop], ^dynamic and drop.inserted_at < ^drop.inserted_at)
  end

  defp apply_filter({:screenshot_status, status}, dynamic) do
    dynamic([drop: drop], ^dynamic and drop.screenshot["status"] in ^status)
  end

  defp apply_filter({:short_id, short_id}, dynamic) do
    dynamic([drop: drop], ^dynamic and drop.short_id == ^short_id)
  end

  defp apply_filter({:user_id, user_id}, dynamic) do
    dynamic([drop: drop], ^dynamic and drop.user_id == ^user_id)
  end

  defp apply_filter({:search, query}, dynamic) when is_binary(query) and query != "" do
    # Use PostgreSQL websearch_to_tsquery for better search experience
    # websearch_to_tsquery handles phrases, AND/OR operators naturally
    dynamic(
      [drop: drop],
      ^dynamic and fragment("? @@ websearch_to_tsquery('english', ?)", drop.search_vector, ^query)
    )
  end

  defp apply_filter({:search, _}, dynamic), do: dynamic

  defp apply_filter({:relevance_rank, {rank, search_query}}, dynamic)
       when is_binary(search_query) and search_query != "" do
    dynamic(
      [drop: drop],
      ^dynamic and
        fragment(
          "ts_rank(?, websearch_to_tsquery('english', ?))",
          drop.search_vector,
          ^search_query
        ) < ^rank
    )
  end

  defp apply_filter(_other, dynamic), do: dynamic

  @doc """
  Gets a single drop given filters.

  ## Examples

      iex> get_drop(%{drop_id: drop_id, user_id: user_id})
      %Drop{}

      iex> get_drop(%{drop_id: drop_id, user_id: user_id})
      nil

  """
  @spec get_drop(filters()) :: drop() | nil
  def get_drop(filters) do
    filter_query = apply_filters()

    drop_query()
    |> where(^filter_query.(filters))
    |> preload([:user])
    |> merge_comment_count()
    |> Repo.one()
  end

  @doc """
  Retrieves a single drop based on its short ID string.

  Returns `nil` if no drop is found with the given string.

  ## Examples

      iex> get_drop_by_short_id("vPfoDMdY")
      %Drop{}

      iex> get_drop_by_short_id("non_existent")
      nil

  """
  @spec get_drop_by_short_id(short_id()) :: drop() | nil
  def get_drop_by_short_id(short_id) do
    case safe_get_drop_by_short_id(short_id) do
      {:ok, result} -> result
      {:error, _reason} -> nil
    end
  end

  defp safe_get_drop_by_short_id(short_id) do
    result =
      drop_query()
      |> where([d], d.short_id == ^short_id)
      |> preload([:user])
      |> merge_comment_count()
      |> Repo.one()

    {:ok, result}
  rescue
    DBConnection.OwnershipError ->
      # Database sandbox not ready yet - return error
      {:error, :db_ownership_error}

    DBConnection.ConnectionError ->
      # Database connection issues - return error
      {:error, :db_connection_error}
  end

  defp merge_comment_count(query) do
    select_merge(query, [d], %{
      comment_count:
        subquery(
          from(c in Comment,
            where: c.drop_id == parent_as(:drop).id,
            select: count(c.id)
          )
        )
    })
  end

  @doc """
  Creates a new drop.

  Returns `{:ok, drop}` if the drop is successfully created, or `{:error, changeset}` if there are validation errors.

  ## Examples

      iex> create_drop(%Drop{}, %User{}, %{
      ...>   title: "drop",
      ...>   description: "A sample drop",
      ...>   short_id: "123abc"
      ...> })
      {:ok, %Drop{}}

      iex> create_drop(%Drop{}, %User{}, %{title: nil})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_drop(drop(), user(), attrs()) :: {:ok, drop()} | {:error, changeset()}
  def create_drop(%Drop{} = _drop, %User{} = user, attrs \\ %{}) do
    prepared_attrs = prepare_drop_attrs(attrs)
    changeset = build_drop_changeset(prepared_attrs, user)

    case Repo.insert(changeset) do
      {:ok, drop} -> handle_create_success(drop)
      {:error, error} -> handle_create_error(error, user, prepared_attrs)
    end
  end

  defp prepare_drop_attrs(attrs) do
    short_id = ShortIdGenerator.generate()

    attrs
    |> Map.put(:short_id, short_id)
    |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)
  end

  defp build_drop_changeset(attrs, user) do
    %Drop{}
    |> Drop.changeset(attrs)
    |> Ecto.Changeset.put_change(:user_id, user.id)
  end

  defp handle_create_success(drop) do
    drop = Repo.preload(drop, [:user])
    :ok = broadcast_drop_creation(drop)
    :ok = invalidate_markdown_cache()
    :ok = invalidate_drop_cache(drop.short_id)
    {:ok, drop}
  end

  defp handle_create_error(%Ecto.Changeset{} = changeset, user, attrs) do
    if changeset.errors[:short_id] do
      # Generate a new short_id and retry
      create_drop(%Drop{}, user, Map.delete(attrs, :short_id))
    else
      {:error, changeset}
    end
  end

  defp handle_create_error(error, _user, _attrs) do
    # Handle other error types
    Logger.error("Unexpected error in create_drop: #{inspect(error)}")
    {:error, error}
  end

  @doc """
  Updates a drop.

  ### Examples

      iex> update_drop(%Drop{}, %User{}, %{
      ...>   title: "Example drop",
      ...>   description: "A sample drop",
      ...>   short_id: "123abc"
      ...> })
      {:ok, %Drop{}}

      iex> update_drop(%Drop{}, %User{}, %{title: nil})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_drop(drop(), user(), attrs()) :: {:ok, drop()} | {:error, changeset()}
  def update_drop(%Drop{} = drop, %User{} = user, attrs \\ %{}) do
    result =
      drop
      |> Drop.changeset(attrs)
      |> Ecto.Changeset.put_assoc(:user, user)
      |> Repo.insert_or_update()

    case result do
      {:ok, updated_drop} ->
        :ok = invalidate_markdown_cache()
        :ok = invalidate_drop_cache(updated_drop.short_id)
        {:ok, updated_drop}

      error ->
        error
    end
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

  defp broadcast_drop_creation(drop) do
    DropsBroadcast.broadcast_drop_creation(drop)
  end

  @doc """
  Invalidates the markdown cache.
  Should be called when drops are created, updated, or deleted.
  """
  @spec invalidate_markdown_cache() :: :ok
  def invalidate_markdown_cache do
    # Clear the formatted markdown cache
    MarkdownCache.clear_all()
  end

  @doc """
  Invalidates the drop cache for a specific short_id.
  Should be called when a specific drop is updated or deleted.
  """
  @spec invalidate_drop_cache(short_id()) :: :ok
  def invalidate_drop_cache(short_id) do
    # Clear the formatted markdown cache for this specific drop
    MarkdownCache.clear_drop(short_id)
  end
end
