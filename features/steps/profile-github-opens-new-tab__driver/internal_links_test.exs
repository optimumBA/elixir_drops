defmodule ProfileGithubOpensNewTab.InternalLinksTest do
  use ElixirDropsWeb.ConnCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Drops.Drop

  # Internal navigation anchors: site-relative links to Drops, Comments, profile,
  # discussion and home pages. The pre-existing "View as Markdown" menu link (.md,
  # which already opens in a new tab) and sponsor redirects (/go/) are not navigation.
  defp internal?(href) do
    String.starts_with?(href, "/") and not String.starts_with?(href, "//") and
      not String.starts_with?(href, "/go/") and not String.ends_with?(href, ".md")
  end

  test "internal and navigation links keep href and have no target", %{conn: conn} do
    owner = user_fixture(%{name: "Ina Internal", github_username: "ina_internal_owner"})
    viewer = user_fixture(%{name: "Val Viewer", github_username: "val_viewer_other"})
    drop = drop_fixture(%Drop{}, owner, %{title: "Internal links piece"})

    for {who, viewer_conn} <- [guest: conn, signed_in: sign_in_user(conn, viewer)] do
      {:ok, _view, html} = live(viewer_conn, ~p"/u/#{owner.id}")

      anchors =
        html
        |> Floki.parse_document!()
        |> Floki.find("a")

      internal =
        Enum.filter(anchors, fn a ->
          a |> Floki.attribute("href") |> List.first("") |> internal?()
        end)

      assert internal != [], "#{who}: no internal links found"

      for a <- internal do
        href = a |> Floki.attribute("href") |> List.first()

        assert Floki.attribute(a, "target") == [],
               "#{who}: internal link #{inspect(href)} has a target"
      end

      hrefs = Enum.flat_map(internal, &Floki.attribute(&1, "href"))

      for expected <- [
            "/u/#{owner.id}/drops",
            "/u/#{owner.id}/comments",
            "/",
            "/d/#{drop.short_id}"
          ] do
        assert expected in hrefs, "#{who}: link #{expected} missing or rewritten: #{inspect(hrefs)}"
      end

      refute Enum.any?(hrefs, &String.contains?(&1, "github.com"))
    end
  end
end
