defmodule ElixirDropsWeb.HealthControllerTest do
  use ElixirDropsWeb.ConnCase, async: true

  describe "GET /health" do
    test "returns cluster info", %{conn: conn} do
      conn = get(conn, ~p"/health")

      assert %{
               "connected_to" => [],
               "hostname" => _,
               "node" => "nonode@nohost",
               "status" => "ok"
             } = json_response(conn, 200)
    end
  end
end
