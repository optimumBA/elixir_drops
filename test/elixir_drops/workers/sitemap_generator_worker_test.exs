defmodule ElixirDrops.Workers.SitemapGeneratorWorkerTest do
  # Changes the shared sitemap file and directory permissions.
  use ElixirDrops.DataCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Workers.SitemapGeneratorWorker

  setup do
    on_exit(fn ->
      [:code.priv_dir(:elixir_drops), "static", "sitemap.xml"]
      |> Path.join()
      |> File.rm()
    end)
  end

  describe "perform/1" do
    test "generates sitemap file successfully" do
      user = user_fixture()
      drop = drop_fixture(user)

      assert {:ok, path} = perform_job(SitemapGeneratorWorker, %{drop_id: drop.id})
      assert File.exists?(path)
      assert String.ends_with?(path, "sitemap.xml")
    end

    test "regenerates the current sitemap when a queued drop has been removed" do
      user = user_fixture()
      drop = drop_fixture(user)
      ElixirDrops.Repo.delete!(drop)

      assert {:ok, path} =
               perform_job(SitemapGeneratorWorker, %{"drop_id" => drop.id})

      refute File.read!(path) =~ "/d/#{drop.short_id}"
    end

    test "handles file system errors" do
      user = user_fixture()
      drop = drop_fixture(user)
      # Temporarily make the sitemap directory read-only
      sitemap_dir = Path.join([:code.priv_dir(:elixir_drops), "static"])
      File.mkdir_p!(sitemap_dir)
      File.chmod!(sitemap_dir, 0o444)
      on_exit(fn -> File.chmod!(sitemap_dir, 0o755) end)

      assert {:error, _reason} = perform_job(SitemapGeneratorWorker, %{drop_id: drop.id})

      # Restore permissions
      File.chmod!(sitemap_dir, 0o755)
    end

    test "regenerates the current sitemap when a queued id is invalid" do
      assert {:ok, path} =
               perform_job(SitemapGeneratorWorker, %{"drop_id" => Ecto.UUID.generate()})

      assert File.exists?(path)
    end

    test "generates full sitemap when no drop_id provided" do
      user = user_fixture()
      _drop = drop_fixture(user)

      assert {:ok, path} = perform_job(SitemapGeneratorWorker, %{})
      assert File.exists?(path)
      assert String.ends_with?(path, "sitemap.xml")
    end

    test "generates empty sitemap when no drops exist and no drop_id provided" do
      assert {:ok, path} = perform_job(SitemapGeneratorWorker, %{})
      assert File.exists?(path)
      assert String.ends_with?(path, "sitemap.xml")
    end
  end
end
