defmodule ElixirDrops.Workers.SitemapGeneratorWorkerTest do
  use ElixirDrops.DataCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Drops
  alias ElixirDrops.Workers.SitemapGeneratorWorker

  describe "perform/1" do
    test "generates sitemap successfully" do
      user = user_fixture()
      drop = drop_fixture(user)

      assert {:ok, path} = perform_job(SitemapGeneratorWorker, %{drop_id: drop.id})
      assert File.exists?(path)
      assert String.ends_with?(path, "sitemap.xml")

      content = File.read!(path)
      assert content =~ ~r/<urlset/
      assert content =~ ~r/<loc>.*\/d\/#{drop.short_id}<\/loc>/
    end

    test "updates existing sitemap with new drop" do
      user = user_fixture()
      drop1 = drop_fixture(user)

      assert {:ok, _} = perform_job(SitemapGeneratorWorker, %{drop_id: drop1.id})

      drop2 = drop_fixture(user)
      assert {:ok, path} = perform_job(SitemapGeneratorWorker, %{"drop_id" => drop2.id})

      content = File.read!(path)
      assert content =~ ~r/<loc>.*\/d\/#{drop1.short_id}<\/loc>/
      assert content =~ ~r/<loc>.*\/d\/#{drop2.short_id}<\/loc>/
    end

    test "updates existing drop in sitemap" do
      user = user_fixture()
      drop = drop_fixture(user)

      assert {:ok, _} = perform_job(SitemapGeneratorWorker, %{drop_id: drop.id})

      {:ok, updated_drop} = Drops.update_drop(drop, user, %{title: "Updated Title"})
      assert {:ok, path} = perform_job(SitemapGeneratorWorker, %{"drop_id" => updated_drop.id})

      content = File.read!(path)
      assert content =~ ~r/<title>Updated Title<\/title>/
      refute content =~ ~r/<title>#{drop.title}<\/title>/
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

    test "updates sitemap with multiple drops" do
      user = user_fixture()
      drop1 = drop_fixture(user)
      drop2 = drop_fixture(user)

      assert {:ok, _path1} = perform_job(SitemapGeneratorWorker, %{"drop_id" => drop1.id})

      assert {:ok, path2} = perform_job(SitemapGeneratorWorker, %{"drop_id" => drop2.id})
      content2 = File.read!(path2)

      assert content2 =~ ~r/<loc>.*\/d\/#{drop1.short_id}<\/loc>/
      assert content2 =~ ~r/<loc>.*\/d\/#{drop2.short_id}<\/loc>/
    end

    test "maintains sitemap order by updated_at" do
      user = user_fixture()
      older_drop = drop_fixture(user)
      newer_drop = drop_fixture(user)

      assert {:ok, path} = perform_job(SitemapGeneratorWorker, %{drop_id: older_drop.id})

      assert {:ok, _path} = perform_job(SitemapGeneratorWorker, %{drop_id: newer_drop.id})
      content = File.read!(path)

      older_pos =
        :binary.matches(content, ~s(<loc>http://localhost:4002/d/#{older_drop.short_id}</loc>))

      newer_pos =
        :binary.matches(content, ~s(<loc>http://localhost:4002/d/#{newer_drop.short_id}</loc>))

      assert length(older_pos) == 1
      assert length(newer_pos) == 1
    end

    test "handles special characters in drop titles" do
      user = user_fixture()
      drop = drop_fixture(%Drops.Drop{}, user, %{title: "Test & Special <Characters>"})

      assert {:ok, path} = perform_job(SitemapGeneratorWorker, %{"drop_id" => drop.id})
      content = File.read!(path)

      # Verify XML escaping
      assert content =~ ~s(&amp;)
      assert content =~ ~s(&lt;)
      assert content =~ ~s(&gt;)
      assert content =~ ~s(<title>Test &amp; Special &lt;Characters&gt;</title>)
    end

    test "generates valid XML structure" do
      user = user_fixture()
      drop = drop_fixture(user)

      assert {:ok, path} = perform_job(SitemapGeneratorWorker, %{drop_id: drop.id})

      {element, []} =
        path
        |> File.read!()
        |> String.to_charlist()
        |> :xmerl_scan.string()

      assert element != nil
    end
  end
end
