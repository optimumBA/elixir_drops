defmodule ElixirDropsWeb.McpController do
  @moduledoc """
  MCP (Model-Context-Protocol) controller for ElixirDrops integration with Cursor.

  ## Usage in Cursor

  To use ElixirDrops in Cursor, add the following configuration to your `.cursor/mcp.json`:

  ```json
  {
    "elixirDrops": {
      "command": "elixir-drops-mcp",
      "args": ["http://localhost:4000/elixir-drops/mcp/search"]
    }
  }
  ```

  This will enable Claude to search through ElixirDrops content directly from Cursor.
  The search endpoint accepts the following query parameters:
  - `q`: Search query string
  - `page`: Page number (default: 1)
  - `per_page`: Results per page (default: 10, max: 50)

  Example response:
  ```json
  {
    "results": [
      {
        "id": "123",
        "title": "Phoenix WebSocket Guide",
        "excerpt": "Learn how to implement WebSocket in Phoenix",
        "author": "John Doe",
        "date": "2024-03-20",
        "url": "https://elixirdrops.net/d/abc123"
      }
    ],
    "total": 1,
    "page": 1,
    "per_page": 10
  }
  ```
  """

  use ElixirDropsWeb, :controller

  alias ElixirDrops.Drops
  alias ElixirDropsWeb.McpJson

  @spec search(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def search(conn, params) do
    query = params["q"] || ""
    page = String.to_integer(params["page"] || "1")
    per_page = min(String.to_integer(params["per_page"] || "10"), 50)

    search_params = %{
      page: page,
      per_page: per_page
    }

    results = Drops.search_drops(query, search_params)
    json = McpJson.search(%{results: results})

    json(conn, json)
  end
end
