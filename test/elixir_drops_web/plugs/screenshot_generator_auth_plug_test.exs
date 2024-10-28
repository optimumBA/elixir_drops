defmodule ElixirDropsWeb.ScreenshotGeneratorAuthPlugTest do
  use ElixirDropsWeb.ConnCase, async: true
  use Plug.Test

  import ElixirDrops.DropsFixtures
  import ElixirDrops.AccountsFixtures

  alias ElixirDrops.Drops.Drop

  defp drop_setup(_attrs) do
    drop_body = ~S"""
    Potenti faucibus quam turpis. \n```go\npackage main\n\nimport \"fmt\"\n\nfunc main() {\n\tfmt.Println(\"Hello, 世界\")\n}\n```\n Cursus vestibulum lobortis lectus nam, nec ullamcorper pellentesque. \n```js\nconst new = () => {\n    console.log(\"js\")\n}\n```\nNunc dignissim magna dapibus mauris malesuada duis. Vivamus augue risus volutpat lacus dolor.\n
    """

    user = user_fixture()
    drop = drop_fixture(%Drop{}, user, %{title: "Drop title", body: drop_body})

    %{drop: drop, user: user}
  end

  describe "call/2" do
    setup [:drop_setup]

    test "clients with valid credentials are allowed", %{conn: conn, drop: drop} do
      _auth = Application.get_env(:elixir_drops, :wallaby_auth)
      username = "elixir_drops_wallaby"
      password = "l3AVAovk4B8g5Sbq"
      # header_content = "Basic " <> Base.encode64("#{auth[:username]}:#{auth[:password]}")
      header_content = "Basic " <> Base.encode64("#{username}:#{password}")

      conn =
        conn
        |> put_req_header("authorization", header_content)
        |> get("/screenshot/#{drop.id}")

      assert conn.status == 200
    end

    test "clients without valid credentials are denied", %{conn: conn, drop: drop} do
      conn = get(conn, "/screenshot/#{drop.id}")

      assert conn.status == 401
      assert conn.resp_body == "Unauthorized"
    end
  end
end
