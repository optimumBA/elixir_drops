defmodule CrawlableArchiveEntry20261121.HomepageLinkTest do
  use ElixirDropsWeb.ConnCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Drops.Drop

  defp text(node), do: node |> Floki.text(sep: " ") |> String.split() |> Enum.join(" ")

  defp attr(attrs, name) do
    case List.keyfind(attrs, name, 0) do
      {_name, value} -> value
      nil -> nil
    end
  end

  # Every anchor with its ancestor trail (nearest first) as {tag, attrs} pairs.
  defp anchors(html), do: html |> Floki.parse_document!() |> walk([])

  defp walk(nodes, trail) when is_list(nodes), do: Enum.flat_map(nodes, &walk(&1, trail))

  defp walk({tag, attrs, children} = node, trail) when is_binary(tag) do
    here = {tag, attrs}

    own =
      if tag == "a",
        do: [%{attrs: attrs, href: attr(attrs, "href"), text: text(node), trail: [here | trail]}],
        else: []

    own ++ walk(children, [here | trail])
  end

  defp walk(_other, _trail), do: []

  defp archive_anchors(html) do
    Enum.filter(anchors(html), fn a ->
      a.href && URI.parse(a.href).path == "/archive"
    end)
  end

  defp hidden?({_tag, attrs}) do
    classes =
      (attr(attrs, "class") || "")
      |> String.split()
      |> Enum.map(&(&1 |> String.split(":") |> List.last()))

    attr(attrs, "hidden") != nil or attr(attrs, "aria-hidden") == "true" or
      Enum.any?(classes, &(&1 in ["hidden", "sr-only", "invisible"]))
  end

  defp assert_body_link(html, label) do
    case archive_anchors(html) do
      [link] ->
        assert link.text == "Browse all Drops", "#{label}: link text is #{inspect(link.text)}"

        refute Enum.any?(link.trail, fn {tag, _} -> tag in ["header", "nav"] end),
               "#{label}: archive link is inside the header or nav"

        assert Enum.any?(link.trail, fn {_tag, attrs} -> attr(attrs, "id") == "main-page-body" end),
               "#{label}: archive link is not inside #main-page-body"

        refute Enum.any?(link.trail, &hidden?/1), "#{label}: archive link is hidden"

        for name <- ["phx-click", "data-phx-link", "target", "download"] do
          assert attr(link.attrs, name) == nil, "#{label}: archive link has #{name}"
        end

        {link_pos, _} = :binary.match(html, ~s(href="/archive"))
        {feed_pos, _} = :binary.match(html, ~s(id="drops"))
        assert link_pos < feed_pos, "#{label}: archive link is not before the feed"

      other ->
        flunk("#{label}: expected exactly one /archive link, got #{length(other)}")
    end
  end

  test "homepage has one visible ordinary body link to the archive and none in the header", %{
    conn: conn
  } do
    user = user_fixture()
    drop_fixture(%Drop{}, user, %{title: "Homepage link drop"})

    assert_body_link(html_response(get(conn, ~p"/"), 200), "signed-out initial HTML")

    {:ok, _view, html} = live(conn, ~p"/")
    assert_body_link(html, "signed-out connected render")

    signed_in = sign_in_user(conn, user)
    assert_body_link(html_response(get(signed_in, ~p"/"), 200), "signed-in initial HTML")

    {:ok, _view, html} = live(signed_in, ~p"/")
    assert_body_link(html, "signed-in connected render")
  end
end
