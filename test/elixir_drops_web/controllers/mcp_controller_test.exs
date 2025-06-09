defmodule ElixirDropsWeb.MCPControllerTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Drops

  describe "search" do
    test "returns search results in JSON format", %{conn: conn} do
      user = user_fixture()

      drop1 =
        drop_fixture(%Drops.Drop{}, user, %{
          title: "Phoenix WebSocket Guide",
          body: "Learn how to implement WebSocket in Phoenix"
        })

      drop_fixture(%Drops.Drop{}, user, %{
        title: "Elixir Basics",
        body: "Introduction to Elixir programming"
      })

      conn = get(conn, ~p"/mcp/search?q=websocket")

      assert json_response(conn, 200) == %{
               "results" => [
                 %{
                   "id" => drop1.id,
                   "title" => "Phoenix WebSocket Guide",
                   "excerpt" => "Learn how to implement WebSocket in Phoenix",
                   "author" => user.name,
                   "date" => Calendar.strftime(drop1.inserted_at, "%Y-%m-%d"),
                   "url" => "https://elixirdrops.net/d/#{drop1.short_id}"
                 }
               ],
               "total" => 1,
               "page" => 1,
               "per_page" => 10
             }
    end

    test "handles pagination correctly", %{conn: conn} do
      user = user_fixture()

      Enum.map(1..15, fn i ->
        drop_fixture(%Drops.Drop{}, user, %{
          title: "Drop #{i}",
          description: "Description for drop #{i}"
        })
      end)

      conn = get(conn, ~p"/mcp/search?page=2&per_page=5")

      response = json_response(conn, 200)
      assert length(response["results"]) == 5
      assert response["total"] == 15
      assert response["page"] == 2
      assert response["per_page"] == 5
    end

    test "handles empty search results", %{conn: conn} do
      conn = get(conn, ~p"/mcp/search?q=nonexistent")

      assert json_response(conn, 200) == %{
               "results" => [],
               "total" => 0,
               "page" => 1,
               "per_page" => 10
             }
    end
  end
end
