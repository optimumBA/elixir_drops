defmodule ElixirDropsWeb.McpTools do
  @moduledoc """
  Defines the available tools for ElixirDrops MCP integration with Claude.
  """

  @doc """
  Returns the list of available tools for Claude to use with ElixirDrops.
  """
  @spec available_tools :: [map()]
  def available_tools do
    [
      %{
        name: "search_elixir_drops",
        description:
          "Search through ElixirDrops content for relevant information about Elixir, Phoenix, and related topics",
        parameters: %{
          type: "object",
          properties: %{
            query: %{
              type: "string",
              description: "The search query to find relevant content"
            },
            page: %{
              type: "integer",
              description: "Page number for pagination (default: 1)"
            },
            per_page: %{
              type: "integer",
              description: "Number of results per page (default: 10, max: 50)"
            }
          },
          required: ["query"]
        }
      }
    ]
  end
end
