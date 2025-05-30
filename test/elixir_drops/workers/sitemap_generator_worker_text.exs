# test/elixir_drops/workers/sitemap_generator_worker_test.exs
defmodule ElixirDrops.Workers.SitemapGeneratorWorkerTest do
  use ElixirDrops.DataCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Workers.SitemapGeneratorWorker

  describe "perform/1" do
    test "generates sitemap successfully" do
      user = user_fixture()
      drop = drop_fixture(user)

      assert {:ok, path} = perform_job(SitemapGeneratorWorker, %{})
      assert File.exists?(path)
      assert String.ends_with?(path, "sitemap.xml")

      # Verify sitemap content
      content = File.read!(path)
      assert content =~ ~r/<urlset/
      assert content =~ ~r/<loc>.*\/d\/#{drop.short_id}<\/loc>/
    end

    test "handles errors gracefully" do
      # Mock File.write to fail
      expect(File, :write, fn _path, _content -> {:error, :enoent} end)

      assert {:error, :enoent} = perform_job(SitemapGeneratorWorker, %{})
    end
  end
end
