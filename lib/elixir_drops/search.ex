defmodule ElixirDrops.Search do
  @moduledoc """
  The Search context.
  """

  import Ecto.Query

  alias ElixirDrops.Repo
  alias ElixirDrops.Search.PopularSearch
  alias ElixirDrops.Search.SearchHistory

  @doc """
  Returns the list of search_histories.

  ## Examples

      iex> list_search_histories()
      [%SearchHistory{}, ...]

  """
  @spec list_search_histories() :: [SearchHistory.t()]
  def list_search_histories do
    Repo.all(SearchHistory)
  end

  @doc """
  Gets a single search_history.

  Raises `Ecto.NoResultsError` if the Search history does not exist.

  ## Examples

      iex> get_search_history!(123)
      %SearchHistory{}

      iex> get_search_history!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_search_history!(binary()) :: SearchHistory.t()
  def get_search_history!(id), do: Repo.get!(SearchHistory, id)

  @doc """
  Creates a search_history.

  ## Examples

      iex> create_search_history(%{field: value})
      {:ok, %SearchHistory{}}

      iex> create_search_history(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_search_history(map()) :: {:ok, SearchHistory.t()} | {:error, Ecto.Changeset.t()}
  def create_search_history(attrs \\ %{}) do
    %SearchHistory{}
    |> SearchHistory.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a search_history.

  ## Examples

      iex> update_search_history(search_history, %{field: new_value})
      {:ok, %SearchHistory{}}

      iex> update_search_history(search_history, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_search_history(SearchHistory.t(), map()) ::
          {:ok, SearchHistory.t()} | {:error, Ecto.Changeset.t()}
  def update_search_history(%SearchHistory{} = search_history, attrs) do
    search_history
    |> SearchHistory.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a search_history.

  ## Examples

      iex> delete_search_history(search_history)
      {:ok, %SearchHistory{}}

      iex> delete_search_history(search_history)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_search_history(SearchHistory.t()) ::
          {:ok, SearchHistory.t()} | {:error, Ecto.Changeset.t()}
  def delete_search_history(%SearchHistory{} = search_history) do
    Repo.delete(search_history)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking search_history changes.

  ## Examples

      iex> change_search_history(search_history)
      %Ecto.Changeset{data: %SearchHistory{}}

  """
  @spec change_search_history(SearchHistory.t(), map()) :: Ecto.Changeset.t()
  def change_search_history(%SearchHistory{} = search_history, attrs \\ %{}) do
    SearchHistory.changeset(search_history, attrs)
  end

  @doc """
  Returns the list of popular_searches.

  ## Examples

      iex> list_popular_searches()
      [%PopularSearch{}, ...]

  """
  @spec list_popular_searches() :: [PopularSearch.t()]
  def list_popular_searches do
    Repo.all(PopularSearch)
  end

  @doc """
  Gets a single popular_search.

  Raises `Ecto.NoResultsError` if the Popular search does not exist.

  ## Examples

      iex> get_popular_search!(123)
      %PopularSearch{}

      iex> get_popular_search!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_popular_search!(binary()) :: PopularSearch.t()
  def get_popular_search!(id), do: Repo.get!(PopularSearch, id)

  @doc """
  Creates a popular_search.

  ## Examples

      iex> create_popular_search(%{field: value})
      {:ok, %PopularSearch{}}

      iex> create_popular_search(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_popular_search(map()) :: {:ok, PopularSearch.t()} | {:error, Ecto.Changeset.t()}
  def create_popular_search(attrs \\ %{}) do
    %PopularSearch{}
    |> PopularSearch.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a popular_search.

  ## Examples

      iex> update_popular_search(popular_search, %{field: new_value})
      {:ok, %PopularSearch{}}

      iex> update_popular_search(popular_search, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_popular_search(PopularSearch.t(), map()) ::
          {:ok, PopularSearch.t()} | {:error, Ecto.Changeset.t()}
  def update_popular_search(%PopularSearch{} = popular_search, attrs) do
    popular_search
    |> PopularSearch.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a popular_search.

  ## Examples

      iex> delete_popular_search(popular_search)
      {:ok, %PopularSearch{}}

      iex> delete_popular_search(popular_search)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_popular_search(PopularSearch.t()) ::
          {:ok, PopularSearch.t()} | {:error, Ecto.Changeset.t()}
  def delete_popular_search(%PopularSearch{} = popular_search) do
    Repo.delete(popular_search)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking popular_search changes.

  ## Examples

      iex> change_popular_search(popular_search)
      %Ecto.Changeset{data: %PopularSearch{}}

  """
  @spec change_popular_search(PopularSearch.t(), map()) :: Ecto.Changeset.t()
  def change_popular_search(%PopularSearch{} = popular_search, attrs \\ %{}) do
    PopularSearch.changeset(popular_search, attrs)
  end

  @doc """
  Gets user search history, limited to last 100 searches, ordered by most recent.

  ## Examples

      iex> get_user_search_history(user_id, 5)
      [%SearchHistory{}, ...]

      iex> get_user_search_history(user_id, 100)
      [%SearchHistory{}, ...]

  """
  @spec get_user_search_history(binary() | nil, integer()) :: [SearchHistory.t()]
  def get_user_search_history(user_id, limit \\ 100)
  def get_user_search_history(nil, _limit), do: []

  def get_user_search_history(user_id, limit) do
    SearchHistory
    |> where([sh], sh.user_id == ^user_id)
    |> order_by([sh], {:desc, sh.inserted_at})
    |> Repo.all()
    |> Enum.uniq_by(& &1.query)
    |> Enum.take(min(limit, 100))
  end

  @doc """
  Deletes a search history entry belonging to the specified user.

  ## Examples

      iex> delete_search_history(search_history_id, user_id)
      {:ok, %SearchHistory{}}

      iex> delete_search_history(non_existent_id, user_id)
      {:error, :not_found}

  """
  @spec delete_search_history(binary(), binary()) ::
          {:ok, SearchHistory.t()} | {:error, :not_found}
  def delete_search_history(search_history_id, user_id) do
    case SearchHistory
         |> where([sh], sh.id == ^search_history_id and sh.user_id == ^user_id)
         |> Repo.one() do
      nil ->
        {:error, :not_found}

      search_history ->
        # Get the query text before deleting
        query_text = search_history.query

        # Delete all occurrences of this query for the user
        {count, _} =
          SearchHistory
          |> where([sh], sh.query == ^query_text and sh.user_id == ^user_id)
          |> Repo.delete_all()

        if count > 0 do
          {:ok, search_history}
        else
          {:error, :not_found}
        end
    end
  end

  @doc """
  Creates or increments a popular search count atomically.

  This function is used to track search popularity by either creating a new
  popular search record or incrementing the count of an existing one.

  ## Examples

      iex> create_or_increment_popular_search("phoenix")
      {:ok, %PopularSearch{query: "phoenix", count: 1}}

      iex> create_or_increment_popular_search("phoenix")
      {:ok, %PopularSearch{query: "phoenix", count: 2}}

  """
  @spec create_or_increment_popular_search(binary()) ::
          {:ok, PopularSearch.t()} | {:error, term()}
  def create_or_increment_popular_search(query) when is_binary(query) do
    track_popular_search(query)
  end

  @doc """
  Tracks a popular search by incrementing its count atomically using upsert.

  ## Examples

      iex> track_popular_search("phoenix")
      {:ok, %PopularSearch{}}

  """
  @spec track_popular_search(String.t()) ::
          {:ok, PopularSearch.t()} | {:error, Ecto.Changeset.t()}
  def track_popular_search(query) when is_binary(query) and query != "" do
    normalized_query =
      query
      |> String.trim()
      |> String.downcase()

    # Use upsert with conflict resolution for atomic increment
    %PopularSearch{}
    |> PopularSearch.changeset(%{query: normalized_query, search_count: 1})
    |> Repo.insert(
      on_conflict: [inc: [search_count: 1]],
      conflict_target: [:query]
    )
  end

  @doc """
  Gets search suggestions using the 2+3 rule: 2 history + 3 popular searches.

  ## Examples

      iex> get_search_suggestions("phoe", user_id)
      [%{query: "phoenix", type: :history}, %{query: "phoenix liveview", type: :popular}]

  """
  @spec get_search_suggestions(binary() | nil, String.t()) :: [map()]
  def get_search_suggestions(user_id, query_prefix)
      when is_binary(query_prefix) or is_nil(query_prefix) do
    if is_nil(query_prefix) do
      []
    else
      get_search_suggestions_impl(query_prefix, user_id)
    end
  end

  defp get_search_suggestions_impl(query_prefix, user_id) when is_binary(query_prefix) do
    trimmed_prefix = String.trim(query_prefix)

    # Handle nil or empty user_id by treating as unauthenticated
    if is_nil(user_id) or user_id == "" do
      get_unauthenticated_suggestions(trimmed_prefix)
    else
      get_authenticated_suggestions(trimmed_prefix, user_id)
    end
  end

  defp get_unauthenticated_suggestions("") do
    # Show top 5 popular searches when no query
    PopularSearch
    |> order_by([ps], {:desc, ps.search_count})
    |> limit(5)
    |> Repo.all()
    |> Enum.map(&%{query: &1.query, type: :popular})
  end

  defp get_unauthenticated_suggestions(prefix) do
    # Filter by prefix
    popular_suggestions = get_matching_popular_suggestions(prefix, [], 5)
    Enum.map(popular_suggestions, &%{query: &1.query, type: :popular})
  end

  defp get_authenticated_suggestions("", user_id) do
    # Show 2 most recent history + 3 popular when no query
    history = get_recent_history(user_id, 2)
    history_queries = Enum.map(history, & &1.query)
    popular = get_popular_excluding(history_queries, 3)

    format_suggestions(history, popular)
  end

  defp get_authenticated_suggestions(prefix, user_id) do
    # Get 2 most recent matching history items
    history_suggestions = get_matching_history_suggestions(prefix, user_id, 2)

    # Get 3 most popular matching suggestions (excluding history matches)
    history_queries = Enum.map(history_suggestions, & &1.query)
    popular_suggestions = get_matching_popular_suggestions(prefix, history_queries, 3)

    format_suggestions(history_suggestions, popular_suggestions)
  end

  defp get_recent_history(user_id, limit) do
    SearchHistory
    |> where([sh], sh.user_id == ^user_id)
    |> order_by([sh], {:desc, sh.inserted_at})
    |> Repo.all()
    |> Enum.uniq_by(& &1.query)
    |> Enum.take(limit)
  end

  defp get_popular_excluding(exclude_queries, limit) do
    PopularSearch
    |> where([ps], ps.query not in ^exclude_queries)
    |> order_by([ps], {:desc, ps.search_count})
    |> limit(^limit)
    |> Repo.all()
  end

  defp format_suggestions(history, popular) do
    history_formatted = Enum.map(history, &%{query: &1.query, type: :history, id: &1.id})
    popular_formatted = Enum.map(popular, &%{query: &1.query, type: :popular})

    history_formatted ++ popular_formatted
  end

  defp get_matching_history_suggestions(_prefix, nil, _limit), do: []

  defp get_matching_history_suggestions(prefix, user_id, limit) do
    SearchHistory
    |> where([sh], sh.user_id == ^user_id)
    |> where([sh], ilike(sh.query, ^"#{prefix}%"))
    |> order_by([sh], {:desc, sh.inserted_at})
    |> limit(^limit)
    |> Repo.all()
  end

  defp get_matching_popular_suggestions(prefix, exclude_queries, limit) do
    PopularSearch
    |> where([ps], ilike(ps.query, ^"#{prefix}%"))
    |> where([ps], ps.query not in ^exclude_queries)
    |> order_by([ps], {:desc, ps.search_count})
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets popular search suggestions for unauthenticated users.

  ## Examples

      iex> get_popular_search_suggestions("phoe", 5)
      [%{query: "phoenix", type: :popular}, %{query: "phoenix liveview", type: :popular}]

  """
  @spec get_popular_search_suggestions(String.t(), integer()) :: [map()]
  def get_popular_search_suggestions(query_prefix, limit \\ 5)
      when is_binary(query_prefix) or is_nil(query_prefix) do
    if is_nil(query_prefix) do
      []
    else
      get_popular_search_suggestions_impl(query_prefix, limit)
    end
  end

  defp get_popular_search_suggestions_impl(query_prefix, limit) when is_binary(query_prefix) do
    trimmed_prefix = String.trim(query_prefix)

    if String.length(trimmed_prefix) < 2 do
      []
    else
      PopularSearch
      |> where([ps], ilike(ps.query, ^"#{trimmed_prefix}%"))
      |> order_by([ps], {:desc, ps.search_count})
      |> limit(^limit)
      |> Repo.all()
      |> Enum.map(&%{query: &1.query, type: :popular})
    end
  end
end
