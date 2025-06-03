defmodule ElixirDrops.SitemapTest do
  use ElixirDrops.DataCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Sitemap

  setup do
    sitemap_dir = Path.join([:code.priv_dir(:elixir_drops), "static"])
    File.mkdir_p!(sitemap_dir)
    File.chmod!(sitemap_dir, 0o755)
    :ok
  end

  describe "generate/0" do
    test "generates sitemap with homepage and drops" do
      user = user_fixture()
      drop = drop_fixture(user)

      assert {:ok, path} = Sitemap.generate(drop)
      assert File.exists?(path)

      content = File.read!(path)

      assert content =~ ~s(<?xml version="1.0" encoding="UTF-8"?>)
      assert content =~ ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">)

      assert content =~ ~s(<url>)
      assert content =~ ~s(<loc>http://localhost:4002/</loc>)
      assert content =~ ~s(<changefreq>daily</changefreq>)
      assert content =~ ~s(<priority>1.0</priority>)

      assert content =~ ~s(<loc>http://localhost:4002/d/#{drop.short_id}</loc>)
      assert content =~ ~s(<title>#{drop.title}</title>)
      assert content =~ ~s(<changefreq>monthly</changefreq>)
      assert content =~ ~s(<priority>0.8</priority>)

      assert content =~
               ~s(<lastmod>#{Date.to_iso8601(NaiveDateTime.to_date(drop.updated_at))}</lastmod>)
    end

    test "handles special characters in URLs" do
      user = user_fixture()
      drop = drop_fixture(%Drop{}, user, %{title: "Test & Special <Characters>"})

      assert {:ok, path} = Sitemap.generate(drop)
      content = File.read!(path)

      assert content =~ ~s(&amp;)
      assert content =~ ~s(&lt;)
      assert content =~ ~s(&gt;)
    end

    test "generates valid XML" do
      user = user_fixture()
      drop = drop_fixture(user)

      assert {:ok, path} = Sitemap.generate(drop)

      {element, []} =
        path
        |> File.read!()
        |> String.to_charlist()
        |> :xmerl_scan.string()

      assert element != nil
    end

    test "handles file system errors" do
      user = user_fixture()
      drop = drop_fixture(user)
      # Temporarily make the sitemap directory read-only
      sitemap_dir = Path.join([:code.priv_dir(:elixir_drops), "static"])
      File.mkdir_p!(sitemap_dir)
      File.chmod!(sitemap_dir, 0o444)

      assert {:error, _} = Sitemap.generate(drop)

      # Restore permissions
      File.chmod!(sitemap_dir, 0o755)
    end
  end

  describe "error handling" do
    test "handles directory creation failure" do
      user = user_fixture()
      drop = drop_fixture(user)

      parent_dir = Path.join([:code.priv_dir(:elixir_drops), "static"])
      File.mkdir_p!(parent_dir)
      File.chmod!(parent_dir, 0o444)

      assert {:error, "Failed to write sitemap file: :eacces"} = Sitemap.generate(drop)

      File.chmod!(parent_dir, 0o755)
    end

    test "handles file update failure" do
      user = user_fixture()
      drop = drop_fixture(user)

      assert {:ok, path} = Sitemap.generate(drop)

      File.chmod!(path, 0o444)

      assert {:error, "Failed to update sitemap file: " <> _} = Sitemap.generate(drop)

      File.chmod!(path, 0o755)
    end
  end

  describe "XML pattern matching" do
    test "updates existing drop entry correctly" do
      user = user_fixture()
      drop = drop_fixture(user)

      assert {:ok, path} = Sitemap.generate(drop)

      {:ok, updated_drop} = Drops.update_drop(drop, user, %{title: "Updated Title"})

      assert {:ok, _} = Sitemap.generate(updated_drop)

      {:ok, content} = File.read(path)

      assert content =~ ~r/<title>Updated Title<\/title>/
      refute content =~ ~r/<title>#{drop.title}<\/title>/

      assert content =~ ~r/<url>\s*<loc>.*\/d\/#{drop.short_id}<\/loc>/
    end

    test "handles special characters in URLs" do
      user = user_fixture()
      drop = drop_fixture(%Drop{}, user, %{title: "Test & Special <Characters>"})

      assert {:ok, path} = Sitemap.generate(drop)

      {:ok, updated_drop} = Drops.update_drop(drop, user, %{title: "New & Special <Title>"})

      assert {:ok, _path} = Sitemap.generate(updated_drop)

      {:ok, content} = File.read(path)

      assert content =~ ~r/<title>New &amp; Special &lt;Title&gt;<\/title>/
    end

    test "maintains XML structure when updating entries" do
      user = user_fixture()
      drop = drop_fixture(user)

      assert {:ok, path} = Sitemap.generate(drop)

      {:ok, updated_drop} = Drops.update_drop(drop, user, %{title: "First Update"})
      assert {:ok, _path} = Sitemap.generate(updated_drop)

      {:ok, updated_drop1} = Drops.update_drop(drop, user, %{title: "Second Update"})
      assert {:ok, _path} = Sitemap.generate(updated_drop1)

      {:ok, content} = File.read(path)

      assert content =~ ~r/<\?xml version="1.0" encoding="UTF-8"\?>/
      assert content =~ ~r/<urlset xmlns="http:\/\/www\.sitemaps\.org\/schemas\/sitemap\/0\.9">/
      assert content =~ ~r/<\/urlset>/

      assert content =~ ~r/<title>Second Update<\/title>/
      refute content =~ ~r/<title>First Update<\/title>/
      refute content =~ ~r/<title>#{drop.title}<\/title>/
    end
  end
end
