defmodule ElixirDrops.SearchFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ElixirDrops.Search` context.
  """

  @doc """
  Generate a search_history.
  """
  @spec search_history_fixture(map()) :: ElixirDrops.Search.SearchHistory.t()
  def search_history_fixture(attrs \\ %{}) do
    # Create a user if user_id is not provided
    user_id = attrs[:user_id] || ElixirDrops.AccountsFixtures.user_fixture().id

    {:ok, search_history} =
      attrs
      |> Enum.into(%{
        query: "some query",
        results_count: 42,
        user_id: user_id
      })
      |> ElixirDrops.Search.create_search_history()

    search_history
  end

  @doc """
  Generate a unique popular_search query.
  """
  @spec unique_popular_search_query() :: String.t()
  def unique_popular_search_query, do: "some query#{System.unique_integer([:positive])}"

  @doc """
  Generate a popular_search.
  """
  @spec popular_search_fixture(map()) :: ElixirDrops.Search.PopularSearch.t()
  def popular_search_fixture(attrs \\ %{}) do
    {:ok, popular_search} =
      attrs
      |> Enum.into(%{
        query: unique_popular_search_query(),
        search_count: 42
      })
      |> ElixirDrops.Search.create_popular_search()

    popular_search
  end
end
