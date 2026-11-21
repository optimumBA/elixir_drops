defmodule LinkPublicContributorAttributions.ViewersTest do
  use ElixirDropsWeb.ConnCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Drops.Drop

  defp text(node), do: node |> Floki.text(sep: " ") |> String.split() |> Enum.join(" ")

  defp path(href), do: href && URI.parse(href).path

  defp profile_anchors(nodes, user) do
    nodes
    |> Floki.find("a")
    |> Enum.filter(fn a -> path(List.first(Floki.attribute(a, "href"))) == "/u/#{user.id}" end)
  end

  defp card(doc, title) do
    doc
    |> Floki.find(".drop-card")
    |> Enum.find(fn c -> c |> Floki.find("h2") |> text() == title end) ||
      flunk("no card titled #{title}")
  end

  defp assert_linked(node, author, others, label) do
    anchors = profile_anchors(node, author)
    assert anchors != [], "#{label}: no link to /u/#{author.id}"
    assert Enum.any?(anchors, fn a -> Floki.find(a, ~s(img[src="#{author.avatar}"])) != [] end),
           "#{label}: avatar of #{author.github_username} is not inside a profile link"

    assert Enum.any?(anchors, fn a -> text(a) =~ author.github_username end),
           "#{label}: name #{author.github_username} is not inside a profile link"

    first = List.first(anchors)
    last = List.last(anchors)
    assert path(List.first(Floki.attribute(first, "href"))) == "/u/#{author.id}"
    assert path(List.first(Floki.attribute(last, "href"))) == "/u/#{author.id}"

    for other <- others do
      assert profile_anchors(node, other) == [], "#{label}: links to /u/#{other.id}"
    end
  end

  test "card and detail author links target the displayed author for guest and third user", %{conn: conn} do
    alpha = user_fixture(%{name: "Alpha Author", github_username: "alpha_author", email: "alpha@private.example"})
    beta = user_fixture(%{name: "Beta Author", github_username: "beta_author", email: "beta@private.example"})
    viewer = user_fixture(%{name: "Third Viewer", github_username: "third_viewer", email: "viewer@private.example"})

    drop_a = drop_fixture(%Drop{}, alpha, %{title: "Attribution fixture Alpha"})
    drop_b = drop_fixture(%Drop{}, beta, %{title: "Attribution fixture Beta"})

    for {label, c} <- [{"guest", conn}, {"third user", sign_in_user(conn, viewer)}] do
      {:ok, view, _html} = live(c, ~p"/")
      doc = view |> render_async() |> Floki.parse_document!()

      assert_linked(card(doc, "Attribution fixture Alpha"), alpha, [beta, viewer], "#{label} home card Alpha")
      assert_linked(card(doc, "Attribution fixture Beta"), beta, [alpha, viewer], "#{label} home card Beta")

      {:ok, dview, _html} = live(c, ~p"/d/#{drop_a.short_id}")
      ddoc = dview |> render_async() |> Floki.parse_document!()
      assert_linked(ddoc, alpha, [beta], "#{label} detail Alpha")

      {:ok, dview, _html} = live(c, ~p"/d/#{drop_b.short_id}")
      ddoc = dview |> render_async() |> Floki.parse_document!()
      assert_linked(ddoc, beta, [alpha], "#{label} detail Beta")
    end
  end
end
