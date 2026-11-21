Code.require_file("support.exs", __DIR__)

defmodule PublicProfileCommentsTabCorrected.PresentationTest do
  use ElixirDropsWeb.ConnCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.CommentsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Drops.Drop
  alias PublicProfileCommentsTabCorrected.Support, as: S

  defp anchors(html) do
    html
    |> S.container()
    |> Floki.find("a")
    |> Enum.map(fn a ->
      {a |> Floki.text(sep: " ") |> String.split() |> Enum.join(" "), List.first(Floki.attribute(a, "href")),
       Floki.attribute(a, "target")}
    end)
  end

  test "entries show drop link, date, markdown, code, reply context and an expand control", %{conn: conn} do
    author = user_fixture(%{name: "Ada Author"})
    rival = user_fixture(%{name: "Rae Rival"})
    drop = drop_fixture(%Drop{}, rival, %{title: "Presentation Drop"})

    parent_body = "PAR-0001 " <> String.duplicate("parent ", 140) <> "PARTAIL"
    parent = comment_fixture(drop, rival, nil, %{body: parent_body})

    reply_body =
      "RPL-0001 reply **boldword** and `inlinecode`\n\n```elixir\nIO.puts(\"codeline\")\n```\n\n[docs](https://example.com/docs)"

    reply = comment_fixture(drop, author, parent, %{body: reply_body})
    long_body = "CMT-0002 " <> String.duplicate("word ", 196) <> "LONGTAIL"
    assert String.length(long_body) <= 1000
    long = comment_fixture(drop, author, nil, %{body: long_body})
    S.set_inserted_at(reply, ~N[2024-03-05 12:00:01])
    S.set_inserted_at(long, ~N[2024-03-05 12:00:00])

    {:ok, view, _} = live(conn, S.comments_path(author))
    html = render_async(view, 10_000)
    container = S.container(html)
    text = S.text(html)

    assert S.tokens(html) == ["RPL-0001", "CMT-0002"]

    # Real Markdown and code, not raw markers.
    assert container |> Floki.find("strong") |> Floki.text() =~ "boldword"
    assert container |> Floki.find("code") |> Floki.text() =~ "inlinecode"
    assert container |> Floki.find("pre") |> Floki.text() =~ "codeline"
    refute text =~ "**boldword**"
    refute text =~ "```"
    assert Enum.any?(anchors(html), fn {_t, href, _} -> href == "https://example.com/docs" end)

    # Drop destination, absolute date, reply context with a short parent excerpt.
    drop_path = "/d/#{drop.short_id}"
    titles = Enum.filter(anchors(html), fn {t, _h, _} -> t == "Presentation Drop" end)
    assert length(titles) >= 2
    assert Enum.all?(titles, fn {_t, href, _} -> URI.parse(href).path == drop_path end)
    assert text =~ "2024"
    assert text =~ ~r/Mar|03/
    assert text =~ "Rae Rival"
    assert Enum.any?(anchors(html), fn {t, href, _} -> t =~ "Rae Rival" and href == "/u/#{rival.id}" end)
    assert text =~ "PAR-0001"
    refute text =~ "PARTAIL"

    # View in discussion once per entry; internal anchors keep same-tab navigation.
    discussion = Enum.filter(anchors(html), fn {t, _h, _} -> t =~ "View in discussion" end)
    assert length(discussion) == 2
    assert Enum.all?(discussion, fn {_t, href, _} -> URI.parse(href).path == drop_path end)

    internal = Enum.filter(anchors(html), fn {_t, href, _} -> is_binary(href) and String.starts_with?(href, "/") end)
    assert Enum.all?(internal, fn {_t, _h, target} -> target == [] end)

    # Long content has an expand control that starts collapsed.
    toggles = Floki.find(container, "button[aria-expanded]")
    assert toggles != []
    assert Enum.all?(toggles, fn b -> Floki.attribute(b, "aria-expanded") == ["false"] end)
  end
end
