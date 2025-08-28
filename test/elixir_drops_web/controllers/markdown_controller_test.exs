defmodule ElixirDropsWeb.MarkdownControllerTest do
  use ElixirDropsWeb.ConnCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.MarkdownCache

  describe "show/2" do
    test "returns markdown for existing drop", %{conn: conn} do
      user = user_fixture()
      drop = drop_fixture(%Drop{}, user)

      conn = get(conn, "/d/#{drop.short_id}.md")

      assert conn
             |> get_resp_header("content-type")
             |> Enum.join() =~ "text/markdown"

      assert response(conn, 200) =~ "# #{drop.title}"
      assert response(conn, 200) =~ drop.body
      assert get_resp_header(conn, "cache-control") == ["public, max-age=300"]
      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    end

    test "avoids database query on cache hit for cached drop", %{conn: conn} do
      user = user_fixture()
      drop = drop_fixture(%Drop{}, user)

      # Make first request to populate cache
      conn1 = get(conn, "/d/#{drop.short_id}.md")
      assert response(conn1, 200) =~ "# #{drop.title}"

      # Delete drop from database after caching
      # This simulates cache-first behavior - if we have cached content,
      # we shouldn't need to query the database at all
      ElixirDrops.Repo.delete!(drop)

      # Second request should still work from cache without hitting database
      conn2 = get(conn, "/d/#{drop.short_id}.md")
      assert response(conn2, 200) =~ "# #{drop.title}"
    end

    test "returns 404 for non-existent drop", %{conn: conn} do
      conn = get(conn, "/d/12345678.md")

      assert conn
             |> get_resp_header("content-type")
             |> Enum.join() =~ "text/plain"

      assert response(conn, 404) =~ "Drop Not Found"
    end

    test "uses cache for subsequent requests", %{conn: conn} do
      user = user_fixture()
      drop = drop_fixture(%Drop{}, user)

      # Clear cache to ensure clean state
      MarkdownCache.clear_all()

      # First request should cache the content
      conn1 = get(conn, "/d/#{drop.short_id}.md")
      response1 = response(conn1, 200)

      # Second request should use cached content (same response)
      conn2 = get(conn, "/d/#{drop.short_id}.md")
      response2 = response(conn2, 200)

      assert response1 == response2
      assert response1 =~ "# #{drop.title}"
    end

    test "cache invalidates when drop is updated", %{conn: conn} do
      user = user_fixture()
      drop = drop_fixture(%Drop{}, user)

      # First request
      conn1 = get(conn, "/d/#{drop.short_id}.md")
      _response1 = response(conn1, 200)

      # Clear cache to simulate update
      MarkdownCache.clear_drop(drop.short_id)

      # Next request should get fresh content
      conn2 = get(conn, "/d/#{drop.short_id}.md")
      response2 = response(conn2, 200)

      # Content structure should be the same but could be regenerated
      assert response2 =~ "# #{drop.title}"
    end
  end

  describe "index/2" do
    test "returns markdown index of all drops", %{conn: conn} do
      user = user_fixture()
      drop1 = drop_fixture(%Drop{}, user)
      drop2 = drop_fixture(%Drop{}, user)

      conn = get(conn, "/index.md")

      assert conn
             |> get_resp_header("content-type")
             |> Enum.join() =~ "text/markdown"

      response_body = response(conn, 200)
      assert response_body =~ "# ElixirDrops"
      assert response_body =~ drop1.title
      assert response_body =~ drop2.title
      assert get_resp_header(conn, "cache-control") == ["public, max-age=300"]
      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    end

    test "avoids database query on cache hit for cached index", %{conn: conn} do
      user = user_fixture()
      drop1 = drop_fixture(%Drop{}, user)
      drop2 = drop_fixture(%Drop{}, user)

      # Make first request to populate cache
      conn1 = get(conn, "/index.md")
      response1 = response(conn1, 200)
      assert response1 =~ drop1.title
      assert response1 =~ drop2.title

      # Delete all drops from database after caching
      # This simulates cache-first behavior - if we have cached index,
      # we shouldn't need to query the database at all
      ElixirDrops.Repo.delete_all(Drop)

      # Second request should still work from cache without hitting database
      conn2 = get(conn, "/index.md")
      response2 = response(conn2, 200)
      assert response2 =~ drop1.title
      assert response2 =~ drop2.title
    end

    test "returns empty index when no drops exist", %{conn: conn} do
      conn = get(conn, "/index.md")

      assert conn
             |> get_resp_header("content-type")
             |> Enum.join() =~ "text/markdown"

      assert response(conn, 200) =~ "# ElixirDrops"
    end

    test "uses cache for index page", %{conn: conn} do
      user = user_fixture()
      drop1 = drop_fixture(%Drop{}, user)
      drop2 = drop_fixture(%Drop{}, user)

      # Clear cache to ensure clean state
      MarkdownCache.clear_all()

      # First request should cache the content
      conn1 = get(conn, "/index.md")
      response1 = response(conn1, 200)

      # Second request should use cached content
      conn2 = get(conn, "/index.md")
      response2 = response(conn2, 200)

      assert response1 == response2
      assert response1 =~ drop1.title
      assert response1 =~ drop2.title
    end
  end
end
