defmodule ElixirDrops.TextSearchHelpers do
  @moduledoc """
  Contains helper functions for performing full text search across contexts
  """

  import Ecto.Query

  @type dynamic_expression :: %Ecto.Query.DynamicExpr{}
  @type query :: Ecto.Query.t()
  @type search_query :: String.t()

  @spec apply_search_ordering(query(), search_query()) :: query()
  def apply_search_ordering(query, search_query)
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

  def apply_search_ordering(query, _no_search) do
    order_by(query, [s], {:desc, s.inserted_at})
  end

  @spec apply_filter({:search, search_query()}, dynamic_expression()) :: dynamic_expression()
  def apply_filter({:search, query}, dynamic) when is_binary(query) and query != "" do
    # Use PostgreSQL websearch_to_tsquery for better search experience
    # websearch_to_tsquery handles phrases, AND/OR operators naturally
    dynamic(
      [drop: drop],
      ^dynamic and
        fragment("? @@ websearch_to_tsquery('english', ?)", drop.search_vector, ^query)
    )
  end

  def apply_filter({:search, _}, dynamic), do: dynamic

  @spec apply_filter({:relevance_rank, {float(), search_query()}}, dynamic_expression()) ::
          dynamic_expression()
  def apply_filter({:relevance_rank, {rank, search_query}}, dynamic)
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
end
