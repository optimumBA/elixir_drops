defmodule ElixirDrops.Workers.SitemapGeneratorWorkerTest do
  use ElixirDrops.DataCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Workers.SitemapGeneratorWorker

  describe "perform/1" do
    test "generates sitemap file successfully" do
      user = user_fixture()
      drop = drop_fixture(user)

      assert {:ok, path} = perform_job(SitemapGeneratorWorker, %{drop_id: drop.id})
      assert File.exists?(path)
      assert String.ends_with?(path, "sitemap.xml")
    end

    test "handles non-existent drop_id" do
      assert {:error, "Drop not found"} =
               perform_job(SitemapGeneratorWorker, %{"drop_id" => Ecto.UUID.generate()})
    end

    test "handles file system errors" do
      user = user_fixture()
      drop = drop_fixture(user)
      # Temporarily make the sitemap directory read-only
      sitemap_dir = Path.join([:code.priv_dir(:elixir_drops), "static"])
      File.mkdir_p!(sitemap_dir)
      File.chmod!(sitemap_dir, 0o444)

      assert {:error, _} = perform_job(SitemapGeneratorWorker, %{drop_id: drop.id})

      # Restore permissions
      File.chmod!(sitemap_dir, 0o755)
    end

    test "handles invalid drop_id format" do
      assert {:error, "Drop not found"} =
               perform_job(SitemapGeneratorWorker, %{"drop_id" => Ecto.UUID.generate()})
    end
  end
end
