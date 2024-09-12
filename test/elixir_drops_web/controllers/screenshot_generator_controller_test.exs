defmodule ElixirDropsWeb.ScreenshotGeneratorControllerTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Drops.Drop

  setup %{conn: conn} do
    user = user_fixture()

    body = ~S"""
    Lorem ipsum
    ```erlang
    -module(hhfuns).
    -compile(export_all).
    one() -> 1.
    two() -> 2.
    add(X,Y) -> X() + Y().
    ```
    ```elixir
    defmodule MyModule do
      def hello do
        :world
      end
    end
    ```
    The end
    """

    drop = drop_fixture(%Drop{}, user, %{body: body, title: "A drop with code blocks"})

    %{conn: conn, user: user, drop: drop}
  end

  describe "/screenshot/:drop_id" do
    test "renders first code block of a drop", %{conn: conn, drop: drop} do
      auth = Application.get_env(:elixir_drops, :wallaby_auth)
      header_content = "Basic " <> Base.encode64("#{auth[:username]}:#{auth[:password]}")

      response =
        conn
        |> put_req_header("authorization", header_content)
        |> get(~p"/screenshot/#{drop.id}")
        |> response(200)

      assert response =~ ~r/<span[^>]+>module[^>]+/
      assert response =~ ~r/<span[^>]+>compile[^>]+/
      assert response =~ ~r/<span[^>]+>add[^>]+/
      refute response =~ ~r/<span[^>]+>defmodule[^>]+/
      refute response =~ ~r/<span[^>]+>hello[^>]+/
      refute response =~ "The end"
    end

    test "cannot access the page without valid credentials", %{conn: conn, drop: drop} do
      conn = get(conn, ~p"/screenshot/#{drop.id}")

      assert response(conn, 401) == "Unauthorized"
    end
  end
end
