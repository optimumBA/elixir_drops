defmodule ElixirDropsWeb.MCPController do
  use ElixirDropsWeb, :controller

  alias ElixirDrops.Drops

  @doc """
  Handles MCP search requests.

  ## Parameters
    * q - Search query string
    * page - Page number (default: 1)
    * per_page - Results per page (default: 10, max: 50)
  """
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

    render(conn, :search, results: results)
  end
end
