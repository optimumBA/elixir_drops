defmodule ElixirDrops.SearchTest do
  use ElixirDrops.DataCase, async: true

  import ElixirDrops.AccountsFixtures

  alias ElixirDrops.Search

  describe "list_search_histories/0" do
    alias ElixirDrops.Search.SearchHistory

    import ElixirDrops.SearchFixtures

    test "returns all search_histories" do
      search_history = search_history_fixture()
      assert Search.list_search_histories() == [search_history]
    end
  end

  describe "get_search_history!/1" do
    alias ElixirDrops.Search.SearchHistory

    import ElixirDrops.SearchFixtures

    test "returns the search_history with given id" do
      search_history = search_history_fixture()
      assert Search.get_search_history!(search_history.id) == search_history
    end
  end

  describe "create_search_history/1" do
    alias ElixirDrops.Search.SearchHistory

    import ElixirDrops.SearchFixtures

    @invalid_attrs %{query: nil, results_count: nil, user_id: nil}

    test "with valid data creates a search_history" do
      user = ElixirDrops.AccountsFixtures.user_fixture()
      valid_attrs = %{query: "some query", results_count: 42, user_id: user.id}

      assert {:ok, %SearchHistory{} = search_history} = Search.create_search_history(valid_attrs)
      assert search_history.query == "some query"
      assert search_history.results_count == 42
      assert search_history.user_id == user.id
    end

    test "with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Search.create_search_history(@invalid_attrs)
    end
  end

  describe "update_search_history/2" do
    alias ElixirDrops.Search.SearchHistory

    import ElixirDrops.SearchFixtures

    @invalid_attrs %{query: nil, results_count: nil, user_id: nil}

    test "with valid data updates the search_history" do
      search_history = search_history_fixture()
      update_attrs = %{query: "some updated query", results_count: 43}

      assert {:ok, %SearchHistory{} = search_history} =
               Search.update_search_history(search_history, update_attrs)

      assert search_history.query == "some updated query"
      assert search_history.results_count == 43
    end

    test "with invalid data returns error changeset" do
      search_history = search_history_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Search.update_search_history(search_history, @invalid_attrs)

      assert search_history == Search.get_search_history!(search_history.id)
    end
  end

  describe "delete_search_history/1" do
    alias ElixirDrops.Search.SearchHistory

    import ElixirDrops.SearchFixtures

    test "deletes the search_history" do
      search_history = search_history_fixture()
      assert {:ok, %SearchHistory{}} = Search.delete_search_history(search_history)
      assert_raise Ecto.NoResultsError, fn -> Search.get_search_history!(search_history.id) end
    end
  end

  describe "change_search_history/1" do
    alias ElixirDrops.Search.SearchHistory

    import ElixirDrops.SearchFixtures

    test "returns a search_history changeset" do
      search_history = search_history_fixture()
      assert %Ecto.Changeset{} = Search.change_search_history(search_history)
    end
  end

  describe "list_popular_searches/0" do
    alias ElixirDrops.Search.PopularSearch

    import ElixirDrops.SearchFixtures

    test "returns all popular_searches" do
      # Get initial count (may have seeded data)
      initial_searches = Search.list_popular_searches()

      popular_search = popular_search_fixture()
      all_searches = Search.list_popular_searches()

      # Check our search is in the list
      assert Enum.any?(all_searches, &(&1.id == popular_search.id))
      assert length(all_searches) == length(initial_searches) + 1
    end
  end

  describe "get_popular_search!/1" do
    alias ElixirDrops.Search.PopularSearch

    import ElixirDrops.SearchFixtures

    test "returns the popular_search with given id" do
      popular_search = popular_search_fixture()
      assert Search.get_popular_search!(popular_search.id) == popular_search
    end
  end

  describe "create_popular_search/1" do
    alias ElixirDrops.Search.PopularSearch

    import ElixirDrops.SearchFixtures

    @invalid_attrs %{query: nil, search_count: nil}

    test "with valid data creates a popular_search" do
      valid_attrs = %{query: "some query", search_count: 42}

      assert {:ok, %PopularSearch{} = popular_search} = Search.create_popular_search(valid_attrs)
      assert popular_search.query == "some query"
      assert popular_search.search_count == 42
    end

    test "with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Search.create_popular_search(@invalid_attrs)
    end
  end

  describe "update_popular_search/2" do
    alias ElixirDrops.Search.PopularSearch

    import ElixirDrops.SearchFixtures

    @invalid_attrs %{query: nil, search_count: nil}

    test "with valid data updates the popular_search" do
      popular_search = popular_search_fixture()
      update_attrs = %{query: "some updated query", search_count: 43}

      assert {:ok, %PopularSearch{} = popular_search} =
               Search.update_popular_search(popular_search, update_attrs)

      assert popular_search.query == "some updated query"
      assert popular_search.search_count == 43
    end

    test "with invalid data returns error changeset" do
      popular_search = popular_search_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Search.update_popular_search(popular_search, @invalid_attrs)

      assert popular_search == Search.get_popular_search!(popular_search.id)
    end
  end

  describe "delete_popular_search/1" do
    alias ElixirDrops.Search.PopularSearch

    import ElixirDrops.SearchFixtures

    test "deletes the popular_search" do
      popular_search = popular_search_fixture()
      assert {:ok, %PopularSearch{}} = Search.delete_popular_search(popular_search)
      assert_raise Ecto.NoResultsError, fn -> Search.get_popular_search!(popular_search.id) end
    end
  end

  describe "change_popular_search/1" do
    alias ElixirDrops.Search.PopularSearch

    import ElixirDrops.SearchFixtures

    test "returns a popular_search changeset" do
      popular_search = popular_search_fixture()
      assert %Ecto.Changeset{} = Search.change_popular_search(popular_search)
    end
  end

  describe "get_search_suggestions/2" do
    import ElixirDrops.SearchFixtures

    test "with empty query returns suggestions" do
      user = user_fixture()
      result = Search.get_search_suggestions(user.id, "")
      # Empty queries now return history and popular suggestions
      assert is_list(result)
    end

    test "with missing query returns empty list" do
      user = user_fixture()
      result = Search.get_search_suggestions(user.id, nil)
      assert result == []
    end

    test "with single character query returns empty list" do
      user = user_fixture()
      result = Search.get_search_suggestions(user.id, "a")
      assert result == []
    end

    test "with whitespace only query returns suggestions" do
      user = user_fixture()
      result = Search.get_search_suggestions(user.id, "   ")
      # Whitespace-only queries now return history and popular suggestions
      assert is_list(result)
    end
  end

  describe "get_popular_search_suggestions/1" do
    import ElixirDrops.SearchFixtures

    test "with empty query returns empty list" do
      result = Search.get_popular_search_suggestions("")
      assert result == []
    end

    test "with missing query returns empty list" do
      result = Search.get_popular_search_suggestions(nil)
      assert result == []
    end

    test "with single character query returns empty list" do
      result = Search.get_popular_search_suggestions("a")
      assert result == []
    end

    test "with whitespace only query returns empty list" do
      result = Search.get_popular_search_suggestions("   ")
      assert result == []
    end

    test "with short query (less than 2 chars) returns empty list" do
      popular_search_fixture(%{query: "elixir", search_count: 10})
      result = Search.get_popular_search_suggestions("e")
      assert result == []
    end
  end

  describe "track_popular_search/1" do
    import ElixirDrops.SearchFixtures

    test "returns an error for a blank query" do
      assert {:error, changeset} = Search.track_popular_search("   ")
      assert "can't be blank" in errors_on(changeset).query
    end

    test "creates new popular search when none exists" do
      query = "new search term"
      initial_count = length(Search.list_popular_searches())

      Search.track_popular_search(query)

      assert length(Search.list_popular_searches()) == initial_count + 1
    end

    test "increments count when popular search exists" do
      existing_popular_search =
        popular_search_fixture(%{query: "existing search", search_count: 5})

      Search.track_popular_search("existing search")

      updated_search = Search.get_popular_search!(existing_popular_search.id)
      assert updated_search.search_count == 6
    end
  end
end
