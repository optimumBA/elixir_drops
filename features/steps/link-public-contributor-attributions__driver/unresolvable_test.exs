defmodule LinkPublicContributorAttributions.UnresolvableTest do
  use ElixirDropsWeb.ConnCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.CommentsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Repo
  alias ElixirDropsWeb.CommentComponents
  alias ElixirDropsWeb.DropComponents

  defp text(node), do: node |> Floki.text(sep: " ") |> String.split() |> Enum.join(" ")

  defp profile_hrefs(html) do
    html
    |> Floki.parse_fragment!()
    |> Floki.find("a")
    |> Enum.map(fn a -> List.first(Floki.attribute(a, "href")) end)
    |> Enum.filter(fn href -> is_binary(href) and String.starts_with?(href, "/u/") or href in ["/u", "/u/", "#", ""] end)
  end

  defp card(html, title) do
    html
    |> Floki.parse_fragment!()
    |> Floki.find(".drop-card")
    |> Enum.find(fn c -> c |> Floki.find("h2") |> text() == title end) ||
      flunk("no card titled #{title}")
  end

  test "unresolvable author is unlinked, resolvable author linked, no private data" do
    good = user_fixture(%{name: "Good Author", github_username: "good_author", email: "good.author@private.example"})
    gone = user_fixture(%{name: "Gone Author", github_username: "gone_author", email: "gone.author@private.example"})
    owner = user_fixture(%{name: "Thread Owner", github_username: "thread_owner", email: "thread.owner@private.example"})

    good_drop = drop_fixture(%Drop{}, good, %{title: "Resolvable fixture drop"}) |> Repo.preload(:user)
    gone_drop = drop_fixture(%Drop{}, gone, %{title: "Unresolvable fixture drop"}) |> Repo.preload(:user)
    thread = drop_fixture(%Drop{}, owner, %{title: "Thread fixture drop"})

    good_comment = comment_fixture(thread, good, nil, %{body: "good body"}) |> Repo.preload([:user, :replies])
    gone_comment = comment_fixture(thread, gone, nil, %{body: "gone body"}) |> Repo.preload([:user, :replies])

    unresolvable_user = %User{id: nil, github_username: nil, avatar: nil, name: nil, email: nil}

    cards =
      for {drop, user} <- [{good_drop, good_drop.user}, {gone_drop, nil}, {gone_drop, unresolvable_user}] do
        render_component(&DropComponents.drop_card/1, %{drop: %{drop | user: user}})
      end

    [good_html, nil_user_html, no_id_html] = cards

    assert profile_hrefs(good_html) |> Enum.member?("/u/#{good.id}"),
           "resolvable author card has no profile link"

    assert profile_hrefs(nil_user_html) == [], "missing author has a profile link"
    assert profile_hrefs(no_id_html) == [], "author without an id has a profile link"

    comments_for = fn comments ->
      render_component(&CommentComponents.comment_section/1, %{
        comment_count: length(comments),
        comment_offset: 0,
        comments: Enum.map(comments, &{"comments-#{&1.id}", &1}),
        current_url: "/d/#{thread.short_id}",
        current_user: nil,
        top_level_comment_count: length(comments)
      })
    end

    good_section = comments_for.([good_comment])
    gone_section = comments_for.([%{gone_comment | user: nil}])

    assert profile_hrefs(good_section) |> Enum.member?("/u/#{good.id}"),
           "resolvable commenter has no profile link"

    assert profile_hrefs(gone_section) == [], "missing commenter has a profile link"

    _ = card(good_html, "Resolvable fixture drop")

    all = Enum.join([good_html, nil_user_html, no_id_html, good_section, gone_section], "\n")

    for secret <- [good.email, gone.email, owner.email, "private.example", "session_token", "user_token"] do
      refute all =~ secret, "rendered output leaks #{inspect(secret)}"
    end

    refute all =~ ~s(href="")
    refute all =~ ~s(href="#")
    refute all =~ "/u/nil"
    refute all =~ "/u/\""
  end
end
