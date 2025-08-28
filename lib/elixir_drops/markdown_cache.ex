defmodule ElixirDrops.MarkdownCache do
  @moduledoc """
  Caches formatted markdown content to avoid regenerating on every request.

  Uses ETS for in-memory storage with 5-minute TTL matching HTTP cache headers.
  """

  require Logger

  @cache_table :markdown_cache
  @ttl_minutes 5
  @ttl_ms @ttl_minutes * 60 * 1000

  @type cache_key :: {:drop, String.t(), integer()} | {:index, non_neg_integer()}
  @type content :: String.t()

  @doc """
  Gets cached formatted markdown content or generates and caches it.

  ## Examples

      iex> get_or_generate(:drop, drop, fn -> MarkdownFormatter.format_drop(drop) end)
      "# Drop Title\\n\\nContent..."
      
  """
  @spec get_or_generate(atom(), term(), function()) :: content()
  def get_or_generate(type, key_data, generator_fn) do
    cache_key = build_cache_key(type, key_data)
    ensure_cache_table()

    case lookup_cache(cache_key) do
      {:hit, content} ->
        Logger.debug("Markdown cache hit for #{inspect(cache_key)}")
        content

      :miss ->
        Logger.debug("Markdown cache miss for #{inspect(cache_key)}")
        content = generator_fn.()
        store_cache(cache_key, content)
        content
    end
  end

  @doc """
  Attempts to get cached content for a drop by short_id without requiring full drop data.
  Returns {:hit, content} if found in cache, :miss if not cached.

  This enables cache-first lookup pattern where we check cache before hitting database.
  """
  @spec get_cached_drop_content(String.t()) :: {:hit, content()} | :miss
  def get_cached_drop_content(short_id) do
    lookup_cached_entries([{{{:drop, short_id, :_}, :"$1", :"$2"}, [], [{{:"$1", :"$2"}}]}])
  end

  @doc """
  Attempts to get cached content for index without requiring full drops data.
  Returns {:hit, content} if found in cache, :miss if not cached.

  This enables cache-first lookup pattern where we check cache before hitting database.
  """
  @spec get_cached_index_content() :: {:hit, content()} | :miss
  def get_cached_index_content do
    lookup_cached_entries([{{{:index, :_}, :"$1", :"$2"}, [], [{{:"$1", :"$2"}}]}])
  end

  @doc """
  Clears all cached markdown content.
  """
  @spec clear_all() :: :ok
  def clear_all do
    case :ets.info(@cache_table) do
      :undefined -> :ok
      _info -> :ets.delete_all_objects(@cache_table)
    end

    :ok
  end

  @doc """
  Clears cached content for a specific drop.
  """
  @spec clear_drop(String.t()) :: :ok
  def clear_drop(short_id) do
    case :ets.info(@cache_table) do
      :undefined ->
        :ok

      _info ->
        # Clear all entries for this drop (any timestamp)
        # Use a function to match on the short_id in the key tuple
        :ets.select_delete(@cache_table, [
          {{{:drop, short_id, :_}, :_, :_}, [], [true]}
        ])

        # Also clear index since it might contain this drop
        :ets.select_delete(@cache_table, [
          {{{:index, :_}, :_, :_}, [], [true]}
        ])
    end

    :ok
  end

  # Private functions

  defp lookup_cached_entries(ets_match_spec) do
    ensure_cache_table()

    case :ets.select(@cache_table, ets_match_spec) do
      [] ->
        :miss

      entries ->
        find_most_recent_valid_entry(entries)
    end
  rescue
    ArgumentError ->
      # Table doesn't exist
      :miss
  end

  defp find_most_recent_valid_entry(entries) do
    current_time = System.system_time(:millisecond)

    most_recent_valid_entry =
      entries
      |> Enum.filter(fn {_content, timestamp} -> current_time - timestamp < @ttl_ms end)
      |> Enum.sort_by(fn {_content, timestamp} -> timestamp end, :desc)
      |> List.first()

    case most_recent_valid_entry do
      nil -> :miss
      {content, _timestamp} -> {:hit, content}
    end
  end

  defp build_cache_key(:drop, %{short_id: short_id, updated_at: updated_at}) do
    {:drop, short_id, timestamp_key(updated_at)}
  end

  defp build_cache_key(:index, drops) when is_list(drops) do
    # Create a composite key based on drop ids and their update times
    # This ensures cache invalidation when any drop changes
    hash =
      drops
      |> Enum.map(fn drop -> {drop.short_id, timestamp_key(drop.updated_at)} end)
      |> :erlang.phash2()

    {:index, hash}
  end

  defp timestamp_key(%{year: y, month: m, day: d, hour: h, minute: min}) do
    # Create a timestamp key that changes every minute
    # This provides additional cache invalidation beyond our TTL
    y * 100_000_000 + m * 1_000_000 + d * 10_000 + h * 100 + min
  end

  defp ensure_cache_table do
    case :ets.info(@cache_table) do
      :undefined ->
        try do
          :ets.new(@cache_table, [:named_table, :public, :set])
          :ok
        rescue
          ArgumentError ->
            # Table was created by another process
            :ok
        end

      _info ->
        :ok
    end
  end

  defp lookup_cache(cache_key) do
    case :ets.lookup(@cache_table, cache_key) do
      [{^cache_key, content, timestamp}] ->
        if System.system_time(:millisecond) - timestamp < @ttl_ms do
          {:hit, content}
        else
          # Expired entry - delete it
          :ets.delete(@cache_table, cache_key)
          :miss
        end

      [] ->
        :miss
    end
  rescue
    ArgumentError ->
      # Table doesn't exist
      :miss
  end

  defp store_cache(cache_key, content) do
    timestamp = System.system_time(:millisecond)

    try do
      :ets.insert(@cache_table, {cache_key, content, timestamp})
      :ok
    rescue
      ArgumentError ->
        # Table doesn't exist, ensure it exists and retry once
        ensure_cache_table()
        :ets.insert(@cache_table, {cache_key, content, timestamp})
        :ok
    end
  end
end
