defmodule ProfileGithubOpensNewTab.RenderedTest do
  use ElixirDropsWeb.ConnCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Drops.Drop

  defp squish(node), do: node |> Floki.text(sep: " ") |> String.split() |> Enum.join(" ")

  test "GitHub link is a native new-tab link for guest and signed-in viewer", %{conn: conn} do
    owner = user_fixture(%{name: "Pia Profile", github_username: "pia_profile_owner"})
    viewer = user_fixture(%{name: "Vic Viewer", github_username: "vic_viewer_other"})
    drop_fixture(%Drop{}, owner, %{title: "Profile owner piece"})

    for {who, viewer_conn} <- [guest: conn, signed_in: sign_in_user(conn, viewer)] do
      {:ok, _view, html} = live(viewer_conn, ~p"/u/#{owner.id}")
      doc = Floki.parse_document!(html)

      anchors =
        doc
        |> Floki.find("a")
        |> Enum.filter(fn a -> squish(a) =~ "View on GitHub" end)

      assert length(anchors) == 1, "#{who}: expected one View on GitHub anchor, saw #{length(anchors)}"
      [anchor] = anchors

      assert squish(anchor) == "View on GitHub"
      assert Floki.attribute(anchor, "href") == ["https://github.com/pia_profile_owner"]
      refute html =~ "https://github.com/vic_viewer_other", "#{who}: viewer's GitHub URL rendered"
      assert Floki.attribute(anchor, "target") == ["_blank"], "#{who}: target must be _blank"

      rel = anchor |> Floki.attribute("rel") |> List.first("") |> String.split()
      assert "noopener" in rel, "#{who}: rel lacks noopener: #{inspect(rel)}"
      assert "noreferrer" in rel, "#{who}: rel lacks noreferrer: #{inspect(rel)}"

      {_tag, attrs, _children} = anchor

      for {name, value} <- attrs do
        refute String.starts_with?(name, "on"), "#{who}: script attribute #{name}"
        refute String.starts_with?(name, "phx-"), "#{who}: LiveView handler #{name}"
        refute String.starts_with?(name, "data-phx"), "#{who}: LiveView hook #{name}"
        refute String.downcase(value) =~ "window.open"
        refute String.downcase(String.trim(value)) =~ ~r/^javascript:/
      end
    end
  end
end
