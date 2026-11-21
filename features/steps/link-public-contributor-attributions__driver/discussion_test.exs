defmodule LinkPublicContributorAttributions.DiscussionTest do
  use ElixirDropsWeb.ConnCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.CommentsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Drops.Drop

  defp text(node), do: node |> Floki.text(sep: " ") |> String.split() |> Enum.join(" ")

  defp path(href), do: href && URI.parse(href).path

  defp profile_anchors(node, user) do
    node
    |> Floki.find("a")
    |> Enum.filter(fn a -> path(List.first(Floki.attribute(a, "href"))) == "/u/#{user.id}" end)
  end

  defp assert_linked(node, author, others, label) do
    anchors = profile_anchors(node, author)
    assert anchors != [], "#{label}: no link to /u/#{author.id}"

    assert Enum.any?(anchors, fn a -> Floki.find(a, ~s(img[src="#{author.avatar}"])) != [] end),
           "#{label}: avatar is not inside a profile link"

    assert Enum.any?(anchors, fn a -> text(a) =~ author.name end),
           "#{label}: visible name #{author.name} is not inside a profile link"

    for other <- others do
      assert profile_anchors(node, other) == [], "#{label}: links to /u/#{other.id}"
    end
  end

  test "comment and reply avatar and name link to their own authors", %{conn: conn} do
    owner = user_fixture(%{name: "Drop Owner", github_username: "drop_owner", email: "owner@private.example"})
    commenter = user_fixture(%{name: "Casey Commenter", github_username: "casey_c", email: "casey@private.example"})
    replier = user_fixture(%{name: "Robin Replier", github_username: "robin_r", email: "robin@private.example"})

    drop = drop_fixture(%Drop{}, owner, %{title: "Discussion fixture drop"})
    comment = comment_fixture(drop, commenter, nil, %{body: "top level body"})
    reply = comment_fixture(drop, replier, comment, %{body: "reply body"})

    {:ok, view, _html} = live(conn, ~p"/d/#{drop.short_id}")
    doc = view |> render_async() |> Floki.parse_document!()

    comment_node =
      doc
      |> Floki.find("#comment-#{comment.id}")
      |> Floki.filter_out(~s([id^="comment-replies-"]))

    reply_node = Floki.find(doc, "#comment-#{reply.id}")

    assert comment_node != [], "top-level comment not rendered"
    assert reply_node != [], "reply not rendered"

    assert_linked(comment_node, commenter, [owner, replier], "top-level comment")
    assert_linked(reply_node, replier, [owner, commenter], "reply")
  end
end
