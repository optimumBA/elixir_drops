defmodule ElixirDrops.SearchTest do
  use ElixirDrops.DataCase, async: true

  import ElixirDrops.AccountsFixtures

  alias ElixirDrops.Search

  describe "search_histories" do
    alias ElixirDrops.Search.SearchHistory

    import ElixirDrops.SearchFixtures

    @invalid_attrs %{query: nil, results_count: nil, user_id: nil}

    test "list_search_histories/0 returns all search_histories" do
      search_history = search_history_fixture()
      assert Search.list_search_histories() == [search_history]
    end

    test "get_search_history!/1 returns the search_history with given id" do
      search_history = search_history_fixture()
      assert Search.get_search_history!(search_history.id) == search_history
    end

    test "create_search_history/1 with valid data creates a search_history" do
      user = ElixirDrops.AccountsFixtures.user_fixture()
      valid_attrs = %{query: "some query", results_count: 42, user_id: user.id}

      assert {:ok, %SearchHistory{} = search_history} = Search.create_search_history(valid_attrs)
      assert search_history.query == "some query"
      assert search_history.results_count == 42
      assert search_history.user_id == user.id
    end

    test "create_search_history/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Search.create_search_history(@invalid_attrs)
    end

    test "update_search_history/2 with valid data updates the search_history" do
      search_history = search_history_fixture()
      update_attrs = %{query: "some updated query", results_count: 43}

      assert {:ok, %SearchHistory{} = search_history} =
               Search.update_search_history(search_history, update_attrs)

      assert search_history.query == "some updated query"
      assert search_history.results_count == 43
    end

    test "update_search_history/2 with invalid data returns error changeset" do
      search_history = search_history_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Search.update_search_history(search_history, @invalid_attrs)

      assert search_history == Search.get_search_history!(search_history.id)
    end

    test "delete_search_history/1 deletes the search_history" do
      search_history = search_history_fixture()
      assert {:ok, %SearchHistory{}} = Search.delete_search_history(search_history)
      assert_raise Ecto.NoResultsError, fn -> Search.get_search_history!(search_history.id) end
    end

    test "change_search_history/1 returns a search_history changeset" do
      search_history = search_history_fixture()
      assert %Ecto.Changeset{} = Search.change_search_history(search_history)
    end
  end

  describe "popular_searches" do
    alias ElixirDrops.Search.PopularSearch

    import ElixirDrops.SearchFixtures

    @invalid_attrs %{query: nil, search_count: nil}

    test "list_popular_searches/0 returns all popular_searches" do
      popular_search = popular_search_fixture()
      assert Search.list_popular_searches() == [popular_search]
    end

    test "get_popular_search!/1 returns the popular_search with given id" do
      popular_search = popular_search_fixture()
      assert Search.get_popular_search!(popular_search.id) == popular_search
    end

    test "create_popular_search/1 with valid data creates a popular_search" do
      valid_attrs = %{query: "some query", search_count: 42}

      assert {:ok, %PopularSearch{} = popular_search} = Search.create_popular_search(valid_attrs)
      assert popular_search.query == "some query"
      assert popular_search.search_count == 42
    end

    test "create_popular_search/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Search.create_popular_search(@invalid_attrs)
    end

    test "update_popular_search/2 with valid data updates the popular_search" do
      popular_search = popular_search_fixture()
      update_attrs = %{query: "some updated query", search_count: 43}

      assert {:ok, %PopularSearch{} = popular_search} =
               Search.update_popular_search(popular_search, update_attrs)

      assert popular_search.query == "some updated query"
      assert popular_search.search_count == 43
    end

    test "update_popular_search/2 with invalid data returns error changeset" do
      popular_search = popular_search_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Search.update_popular_search(popular_search, @invalid_attrs)

      assert popular_search == Search.get_popular_search!(popular_search.id)
    end

    test "delete_popular_search/1 deletes the popular_search" do
      popular_search = popular_search_fixture()
      assert {:ok, %PopularSearch{}} = Search.delete_popular_search(popular_search)
      assert_raise Ecto.NoResultsError, fn -> Search.get_popular_search!(popular_search.id) end
    end

    test "change_popular_search/1 returns a popular_search changeset" do
      popular_search = popular_search_fixture()
      assert %Ecto.Changeset{} = Search.change_popular_search(popular_search)
    end
  end

  describe "search suggestions" do
    import ElixirDrops.SearchFixtures

    test "get_search_suggestions/2 with empty query returns empty list" do
      user = user_fixture()
      result = Search.get_search_suggestions(user.id, "")
      assert result == []
    end

    test "get_search_suggestions/2 with nil query returns empty list" do
      user = user_fixture()
      result = Search.get_search_suggestions(nil, user.id)
      assert result == []
    end

    test "get_search_suggestions/2 with single character query returns empty list" do
      user = user_fixture()
      result = Search.get_search_suggestions(user.id, "a")
      assert result == []
    end

    test "get_popular_search_suggestions/1 with empty query returns empty list" do
      result = Search.get_popular_search_suggestions("")
      assert result == []
    end

    test "get_popular_search_suggestions/1 with nil query returns empty list" do
      result = Search.get_popular_search_suggestions(nil)
      assert result == []
    end

    test "get_popular_search_suggestions/1 with single character query returns empty list" do
      result = Search.get_popular_search_suggestions("a")
      assert result == []
    end

    test "get_search_suggestions/2 with whitespace only query returns empty list" do
      user = user_fixture()
      result = Search.get_search_suggestions(user.id, "   ")
      assert result == []
    end

    test "get_popular_search_suggestions/1 with whitespace only query returns empty list" do
      result = Search.get_popular_search_suggestions("   ")
      assert result == []
    end

    test "get_popular_search_suggestions/1 with short query (less than 2 chars) returns empty list" do
      popular_search_fixture(%{query: "elixir", search_count: 10})
      result = Search.get_popular_search_suggestions("e")
      assert result == []
    end

    test "track_popular_search/1 creates new popular search when none exists" do
      query = "new search term"
      initial_count = length(Search.list_popular_searches())

      Search.track_popular_search(query)

      assert length(Search.list_popular_searches()) == initial_count + 1
    end

    test "track_popular_search/1 increments count when popular search exists" do
      existing_popular_search =
        popular_search_fixture(%{query: "existing search", search_count: 5})

      Search.track_popular_search("existing search")

      updated_search = Search.get_popular_search!(existing_popular_search.id)
      assert updated_search.search_count == 6
    end
  end
end
