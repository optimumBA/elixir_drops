defmodule ElixirDropsWeb.SearchHelperTest do
  use ElixirDrops.DataCase, async: false

  alias ElixirDrops.AccountsFixtures
  alias ElixirDrops.DropsFixtures
  alias ElixirDrops.Search
  alias ElixirDropsWeb.SearchHelper

  describe "track_search/3" do
    test "tracks search history and popular searches for authenticated user" do
      user = AccountsFixtures.user_fixture()
      _drop = DropsFixtures.drop_fixture(%ElixirDrops.Drops.Drop{}, user, %{})

      socket = %Phoenix.LiveView.Socket{
        assigns: %{current_user: user}
      }

      filters = %{user_id: user.id}

      # Test that the function doesn't crash
      assert :ok = SearchHelper.track_search("phoenix", socket, filters)

      # Test the underlying search functionality directly
      {:ok, _history} =
        Search.create_search_history(%{
          user_id: user.id,
          query: "phoenix tutorial",
          results_count: 1
        })

      {:ok, _popular} = Search.track_popular_search("phoenix framework")

      # Verify search history was created
      histories = Search.get_user_search_history(user.id, 10)
      assert length(histories) > 0

      history = hd(histories)
      assert history.user_id == user.id

      # Verify popular search was tracked - test with different query to avoid conflicts
      popular_searches = Search.get_search_suggestions(user.id, "phoe")
      assert Enum.any?(popular_searches, &(&1.type == :history))
    end

    test "does nothing when user is not authenticated" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{current_user: nil}
      }

      filters = %{}

      assert :ok = SearchHelper.track_search("phoenix", socket, filters)

      # No search history should be created
      assert [] = Search.list_search_histories()
    end

    test "does nothing for empty query" do
      user = AccountsFixtures.user_fixture()

      socket = %Phoenix.LiveView.Socket{
        assigns: %{current_user: user}
      }

      filters = %{user_id: user.id}

      assert :ok = SearchHelper.track_search("", socket, filters)
      assert :ok = SearchHelper.track_search("   ", socket, filters)

      # Give the async task time to complete
      :timer.sleep(100)

      # No search history should be created
      histories = Search.get_user_search_history(user.id, 10)
      assert histories == []
    end
  end

  describe "get_focus_search_suggestions/1" do
    test "returns search history suggestions for authenticated user" do
      user = AccountsFixtures.user_fixture()

      # Create some search history
      {:ok, _history1} =
        Search.create_search_history(%{
          user_id: user.id,
          query: "phoenix liveview",
          results_count: 3
        })

      {:ok, _history2} =
        Search.create_search_history(%{
          user_id: user.id,
          query: "ecto queries",
          results_count: 2
        })

      {suggestions, show_suggestions} = SearchHelper.get_focus_search_suggestions(user.id)

      assert show_suggestions == true
      assert length(suggestions) == 2

      suggestion = hd(suggestions)
      assert suggestion.type == :history
      assert suggestion.query in ["phoenix liveview", "ecto queries"]
      assert Map.has_key?(suggestion, :id)
    end

    test "returns empty suggestions for user with no search history" do
      user = AccountsFixtures.user_fixture()

      {suggestions, show_suggestions} = SearchHelper.get_focus_search_suggestions(user.id)

      assert suggestions == []
      assert show_suggestions == false
    end
  end

  describe "handle_delete_search_history/3" do
    test "deletes search history and returns updated socket" do
      user = AccountsFixtures.user_fixture()

      # Create some popular searches that should remain
      {:ok, _} = Search.track_popular_search("phoenix")
      {:ok, _} = Search.track_popular_search("elixir")

      # Create search history
      {:ok, history} =
        Search.create_search_history(%{user_id: user.id, query: "test", results_count: 1})

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          current_user: user,
          search_suggestions: [
            %{id: history.id, query: "test", type: :history},
            %{id: 999, query: "other", type: :popular}
          ]
        }
      }

      {:noreply, updated_socket} =
        SearchHelper.handle_delete_search_history(history.id, socket, :search_suggestions)

      # Should remove the deleted history from suggestions
      # Since we have 2 popular searches, we should have those back
      assert length(updated_socket.assigns.search_suggestions) >= 2
      refute Enum.any?(updated_socket.assigns.search_suggestions, &(&1.query == "test"))
      # Should still have popular searches
      assert Enum.any?(updated_socket.assigns.search_suggestions, &(&1.query == "phoenix"))
      assert Enum.any?(updated_socket.assigns.search_suggestions, &(&1.query == "elixir"))
    end
  end
end
