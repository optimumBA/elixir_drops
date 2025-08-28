defmodule ElixirDrops.MarkdownCacheTest do
  use ElixirDrops.DataCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.MarkdownCache

  describe "get_or_generate/3" do
    test "caches formatted content on first call" do
      user = user_fixture()
      drop = drop_fixture(%Drop{}, user)

      # First call should generate content
      content1 =
        MarkdownCache.get_or_generate(:drop, drop, fn ->
          "Generated content #{System.unique_integer()}"
        end)

      # Second call should return cached content (same value)
      content2 =
        MarkdownCache.get_or_generate(:drop, drop, fn ->
          "This should not be called #{System.unique_integer()}"
        end)

      assert content1 == content2
      assert content1 =~ "Generated content"
      refute content2 =~ "This should not be called"
    end

    test "cache expires after TTL" do
      user = user_fixture()
      drop = drop_fixture(%Drop{}, user)

      # Generate initial content
      content1 =
        MarkdownCache.get_or_generate(:drop, drop, fn ->
          "Initial content"
        end)

      # Manually expire the cache by setting an old timestamp
      cache_key = {:drop, drop.short_id, timestamp_key(drop.updated_at)}
      # 6 minutes ago
      old_timestamp = System.system_time(:millisecond) - 6 * 60 * 1000
      :ets.insert(:markdown_cache, {cache_key, content1, old_timestamp})

      # Next call should regenerate
      content2 =
        MarkdownCache.get_or_generate(:drop, drop, fn ->
          "Regenerated content"
        end)

      assert content2 == "Regenerated content"
    end

    test "different drops have different cache keys" do
      user = user_fixture()
      drop1 = drop_fixture(%Drop{}, user)
      drop2 = drop_fixture(%Drop{}, user)

      content1 =
        MarkdownCache.get_or_generate(:drop, drop1, fn ->
          "Content for drop 1"
        end)

      content2 =
        MarkdownCache.get_or_generate(:drop, drop2, fn ->
          "Content for drop 2"
        end)

      assert content1 == "Content for drop 1"
      assert content2 == "Content for drop 2"
    end

    test "index cache works with list of drops" do
      user = user_fixture()
      drop1 = drop_fixture(%Drop{}, user)
      drop2 = drop_fixture(%Drop{}, user)
      drops = [drop1, drop2]

      # First call generates
      content1 =
        MarkdownCache.get_or_generate(:index, drops, fn ->
          "Index content #{System.unique_integer()}"
        end)

      # Second call uses cache
      content2 =
        MarkdownCache.get_or_generate(:index, drops, fn ->
          "Should not be called"
        end)

      assert content1 == content2
      assert content1 =~ "Index content"
    end
  end

  describe "clear_drop/1" do
    test "clears cache for specific drop" do
      user = user_fixture()
      drop = drop_fixture(%Drop{}, user)

      # Cache some content
      _content =
        MarkdownCache.get_or_generate(:drop, drop, fn ->
          "Cached content"
        end)

      # Clear the cache
      MarkdownCache.clear_drop(drop.short_id)

      # Next call should regenerate
      new_content =
        MarkdownCache.get_or_generate(:drop, drop, fn ->
          "New content after clear"
        end)

      assert new_content == "New content after clear"
    end

    test "handles clearing when table doesn't exist" do
      # Clear all to ensure clean state
      MarkdownCache.clear_all()

      # Delete the ETS table if it exists
      case :ets.info(:markdown_cache) do
        :undefined -> :ok
        _info -> :ets.delete(:markdown_cache)
      end

      # This should not crash when table doesn't exist
      assert MarkdownCache.clear_drop("nonexistent") == :ok
    end
  end

  describe "clear_all/0" do
    test "clears all cached content" do
      user = user_fixture()
      drop1 = drop_fixture(%Drop{}, user)
      drop2 = drop_fixture(%Drop{}, user)

      # Cache some content
      MarkdownCache.get_or_generate(:drop, drop1, fn -> "Content 1" end)
      MarkdownCache.get_or_generate(:drop, drop2, fn -> "Content 2" end)

      # Clear all
      MarkdownCache.clear_all()

      # Both should regenerate
      new1 = MarkdownCache.get_or_generate(:drop, drop1, fn -> "New 1" end)
      new2 = MarkdownCache.get_or_generate(:drop, drop2, fn -> "New 2" end)

      assert new1 == "New 1"
      assert new2 == "New 2"
    end

    test "handles clearing when table doesn't exist" do
      # Delete the ETS table if it exists
      case :ets.info(:markdown_cache) do
        :undefined -> :ok
        _info -> :ets.delete(:markdown_cache)
      end

      # This should not crash when table doesn't exist
      assert MarkdownCache.clear_all() == :ok
    end
  end

  describe "error handling and edge cases" do
    test "lookup_cache handles missing ETS table gracefully" do
      user = user_fixture()
      drop = drop_fixture(%Drop{}, user)

      # Delete the ETS table to simulate it not existing
      case :ets.info(:markdown_cache) do
        :undefined -> :ok
        _info -> :ets.delete(:markdown_cache)
      end

      # This should handle the ArgumentError when table doesn't exist
      result =
        MarkdownCache.get_or_generate(:drop, drop, fn ->
          "Content generated after table recreation"
        end)

      assert result == "Content generated after table recreation"
    end

    test "find_most_recent_valid_entry handles empty entries" do
      user = user_fixture()
      drop = drop_fixture(%Drop{}, user)

      # First ensure table exists and add some content
      MarkdownCache.get_or_generate(:drop, drop, fn -> "test" end)

      # Now manually modify the cache to have expired content
      cache_key = {:drop, drop.short_id, timestamp_key(drop.updated_at)}
      # 10 minutes ago (past TTL)
      expired_timestamp = System.system_time(:millisecond) - 10 * 60 * 1000
      :ets.insert(:markdown_cache, {cache_key, "expired", expired_timestamp})

      # This should trigger the nil case when no valid entries exist
      result =
        MarkdownCache.get_or_generate(:drop, drop, fn ->
          "Content after expiry"
        end)

      assert result == "Content after expiry"
    end

    test "store_cache handles missing table and recreates it" do
      user = user_fixture()
      drop = drop_fixture(%Drop{}, user)

      # Delete the ETS table to simulate it not existing during storage
      case :ets.info(:markdown_cache) do
        :undefined -> :ok
        _info -> :ets.delete(:markdown_cache)
      end

      # This should handle the ArgumentError and recreate the table
      result =
        MarkdownCache.get_or_generate(:drop, drop, fn ->
          "Content stored after table recreation"
        end)

      assert result == "Content stored after table recreation"

      # Verify the table was recreated and content is accessible
      cached_result =
        MarkdownCache.get_or_generate(:drop, drop, fn ->
          "Should not be called"
        end)

      assert cached_result == "Content stored after table recreation"
    end

    test "clear_cache handles missing ETS table gracefully" do
      # Delete the ETS table if it exists
      case :ets.info(:markdown_cache) do
        :undefined -> :ok
        _info -> :ets.delete(:markdown_cache)
      end

      # This should handle ArgumentError when table doesn't exist during clear
      user = user_fixture()
      drop = drop_fixture(%Drop{}, user)

      # First call should work despite missing table
      result =
        MarkdownCache.get_or_generate(:drop, drop, fn ->
          "Content generated"
        end)

      assert result == "Content generated"
    end

    test "ensure_cache_table creates table when it doesn't exist" do
      # Delete the table to start fresh
      case :ets.info(:markdown_cache) do
        :undefined -> :ok
        _info -> :ets.delete(:markdown_cache)
      end

      user = user_fixture()
      drop = drop_fixture(%Drop{}, user)

      # This should create the table automatically
      result = MarkdownCache.get_or_generate(:drop, drop, fn -> "Test content" end)

      assert result == "Test content"

      # Verify the table was created and content is accessible
      cached_result = MarkdownCache.get_or_generate(:drop, drop, fn -> "Should not be called" end)
      assert cached_result == "Test content"

      # Verify the table exists
      assert :ets.info(:markdown_cache) != :undefined
    end
  end

  # Helper function to match the one in MarkdownCache
  defp timestamp_key(%{year: y, month: m, day: d, hour: h, minute: min}) do
    y * 100_000_000 + m * 1_000_000 + d * 10_000 + h * 100 + min
  end
end
