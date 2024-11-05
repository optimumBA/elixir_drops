defmodule ElixirDropsWeb.CodeSnippetControllerTest do
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

    drop_with_no_code_block =
      drop_fixture(%Drop{}, user, %{body: "No code block", title: "A drop without code blocks"})

    %{conn: conn, user: user, drop: drop, drop_with_no_code_block: drop_with_no_code_block}
  end

  describe "/d/:drop_id/code_snippet" do
    test "renders first code block of a drop", %{conn: conn, drop: drop} do
      auth = Application.get_env(:elixir_drops, :wallaby_auth)

      header_content = "Basic " <> Base.encode64("#{auth[:username]}:#{auth[:password]}")

      response =
        conn
        |> put_req_header("authorization", header_content)
        |> get(~p"/d/#{drop.id}/code_snippet")
        |> response(200)

      assert response =~ ~r/<span[^>]+>module[^>]+/
      assert response =~ ~r/<span[^>]+>compile[^>]+/
      assert response =~ ~r/<span[^>]+>add[^>]+/
      refute response =~ ~r/<span[^>]+>defmodule[^>]+/
      refute response =~ ~r/<span[^>]+>hello[^>]+/
      refute response =~ "The end"
    end

    test "returns 404 when no code block is found", %{
      conn: conn,
      drop_with_no_code_block: drop_with_no_code_block
    } do
      auth = Application.get_env(:elixir_drops, :wallaby_auth)
      header_content = "Basic " <> Base.encode64("#{auth[:username]}:#{auth[:password]}")

      response =
        conn
        |> put_req_header("authorization", header_content)
        |> get(~p"/d/#{drop_with_no_code_block.id}/code_snippet")
        |> response(404)

      assert response =~ "404 Not Found"
    end

    test "returns 404 when drop is not found", %{conn: conn} do
      auth = Application.get_env(:elixir_drops, :wallaby_auth)
      header_content = "Basic " <> Base.encode64("#{auth[:username]}:#{auth[:password]}")

      response =
        conn
        |> put_req_header("authorization", header_content)
        |> get(~p"/d/#{Ecto.UUID.generate()}/code_snippet")
        |> response(404)

      assert response =~ "404 Not Found"
    end

    test "clients with valid credentials are allowed", %{conn: conn, drop: drop} do
      auth = Application.get_env(:elixir_drops, :wallaby_auth)

      header_content = "Basic " <> Base.encode64("#{auth[:username]}:#{auth[:password]}")

      conn =
        conn
        |> put_req_header("authorization", header_content)
        |> get("/d/#{drop.id}/code_snippet")

      assert conn.status == 200
    end

    test "cannot access the page without valid credentials", %{conn: conn, drop: drop} do
      conn = get(conn, ~p"/d/#{drop.id}/code_snippet")

      assert response(conn, 401) == "Unauthorized"
    end

    test "returns 401 if authentication header is missing", %{conn: conn, drop: drop} do
      conn = get(conn, "/d/#{drop.id}/code_snippet")

      assert response(conn, 401) == "Unauthorized"
    end
  end
end
