defmodule ElixirDrops.SitemapTest do
  use ElixirDrops.DataCase, async: false
  use ElixirDropsWeb, :verified_routes

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Repo
  alias ElixirDrops.Sitemap

  setup do
    sitemap_dir = Path.join([:code.priv_dir(:elixir_drops), "static"])
    sitemap_path = Path.join(sitemap_dir, "sitemap.xml")
    File.mkdir_p!(sitemap_dir)
    File.chmod!(sitemap_dir, 0o755)
    File.rm(sitemap_path)

    on_exit(fn -> File.rm(sitemap_path) end)

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
      # Verify homepage URL exists (any valid URL format)
      assert content =~ ~r/<loc>[^<]*\/<\/loc>/
      assert content =~ ~s(<changefreq>daily</changefreq>)
      assert content =~ ~s(<priority>1.0</priority>)
      assert content =~ ~s(<loc>#{url(~p"/archive")}</loc>)

      # Verify drop URL exists with correct short_id
      assert content =~ ~r/<loc>[^<]*\/d\/#{drop.short_id}<\/loc>/
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

      # Verify drop URL exists with correct short_id
      assert content =~ ~r/<loc>[^<]*\/d\/#{drop.short_id}<\/loc>/
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
      on_exit(fn -> File.chmod!(sitemap_dir, 0o755) end)

      assert {:error, _reason} = Sitemap.generate(drop)

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
      on_exit(fn -> File.chmod!(parent_dir, 0o755) end)

      assert {:error, "Failed to write sitemap file: :eacces"} = Sitemap.generate(drop)

      File.chmod!(parent_dir, 0o755)
    end

    test "atomically replaces a read-only sitemap file" do
      user = user_fixture()
      drop = drop_fixture(user)

      assert {:ok, path} = Sitemap.generate(drop)

      File.chmod!(path, 0o444)
      on_exit(fn -> File.chmod!(path, 0o644) end)

      assert {:ok, ^path} = Sitemap.generate(drop)
      assert File.read!(path) =~ "/d/#{drop.short_id}"

      File.chmod!(path, 0o755)
    end
  end

  describe "regeneration" do
    test "keeps publications newest first and removes deleted drops" do
      user = user_fixture()
      original_older_drop = drop_fixture(user)
      older_drop = update_drop_inserted_at(original_older_drop, -3_600)

      assert {:ok, path} = Sitemap.generate(older_drop)

      newer_drop = drop_fixture(user)
      assert {:ok, _path} = Sitemap.generate(newer_drop)

      newest_first_content = File.read!(path)
      newer_url = url(~p"/d/#{newer_drop.short_id}")
      older_url = url(~p"/d/#{older_drop.short_id}")
      assert {newer_position, _length} = :binary.match(newest_first_content, newer_url)
      assert {older_position, _length} = :binary.match(newest_first_content, older_url)
      assert newer_position < older_position

      {:ok, updated_drop} = Drops.update_drop(older_drop, user, %{title: "Updated title"})
      assert {:ok, _path} = Sitemap.generate(updated_drop)

      updated_date =
        updated_drop.updated_at
        |> NaiveDateTime.to_date()
        |> Date.to_iso8601()

      updated_content = File.read!(path)

      assert updated_content =~
               ~r/<url>\s*<loc>#{Regex.escape(older_url)}<\/loc>\s*<lastmod>#{updated_date}<\/lastmod>/

      assert {newer_position, _length} = :binary.match(updated_content, newer_url)
      assert {older_position, _length} = :binary.match(updated_content, older_url)
      assert newer_position < older_position

      Repo.delete!(newer_drop)
      assert {:ok, _path} = Sitemap.generate(updated_drop)

      content_after_delete = File.read!(path)
      refute content_after_delete =~ newer_url
      assert content_after_delete =~ older_url
      assert content_after_delete =~ ~r/<\?xml version="1.0" encoding="UTF-8"\?>/

      assert content_after_delete =~
               ~r/<urlset xmlns="http:\/\/www\.sitemaps\.org\/schemas\/sitemap\/0\.9">/

      assert content_after_delete =~ ~r/<\/urlset>/
    end

    test "escapes sitemap URLs and preserves lastmod from updated_at" do
      user = user_fixture()
      drop = drop_fixture(%Drop{}, user, %{title: "Test & Special <Characters>"})

      assert {:ok, path} = Sitemap.generate(drop)

      {:ok, updated_drop} = Drops.update_drop(drop, user, %{title: "New & Special <Title>"})
      assert {:ok, ^path} = Sitemap.generate(updated_drop)

      content = File.read!(path)

      updated_date =
        updated_drop.updated_at
        |> NaiveDateTime.to_date()
        |> Date.to_iso8601()

      assert content =~ "#{url(~p"/d/#{drop.short_id}")}"
      assert content =~ "<lastmod>#{updated_date}</lastmod>"
    end
  end
end
