defmodule PublicProfilePageAndDropsTab.ProfilePageTest do
  use ElixirDropsWeb.ConnCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.CommentsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Accounts
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Repo
  alias ElixirDrops.Search

  @states ~w(idle loading retry empty exhausted)

  defp elements(nodes) when is_list(nodes), do: Enum.flat_map(nodes, &elements/1)

  defp elements({tag, attrs, children}) when is_binary(tag),
    do: [{tag, attrs, children} | elements(children)]

  defp elements(_other), do: []

  defp squish(node), do: node |> Floki.text(sep: " ") |> String.split() |> Enum.join(" ")

  defp links(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("a")
    |> Enum.map(fn a -> {squish(a), List.first(Floki.attribute(a, "href"))} end)
  end

  defp own_profile_href(conn, user) do
    {:ok, _view, html} = live(sign_in_user(conn, user), ~p"/")

    case Enum.find(links(html), fn {text, _href} -> text =~ "View public profile" end) do
      {_text, href} when is_binary(href) -> href
      nil -> flunk("account menu of #{user.github_username} has no View public profile link")
    end
  end

  defp path_for(href, owner, other) do
    href
    |> String.replace(owner.id, other.id)
    |> String.replace(owner.github_username, other.github_username)
  end

  defp tab_href(html, base, label) do
    base_path = URI.parse(base).path
    label_re = Regex.compile!("^#{label}(\\s+\\d+)?$")

    found =
      Enum.find(links(html), fn {text, href} ->
        path = href && URI.parse(href).path

        Regex.match?(label_re, text) and
          (path == base_path or String.starts_with?(path || "", base_path <> "/"))
      end)

    case found do
      {_text, href} -> href
      nil -> flunk("no #{label} tab link under #{base_path}")
    end
  end

  # A total is any element whose whole visible text is the label with an integer
  # next to it ("3 Drops" or "Drops 3"); all such elements must agree.
  defp total(html, label) do
    re = Regex.compile!("^(?:#{label}s?:?\\s*(\\d+)|(\\d+)\\s*#{label}s?)$")

    values =
      html
      |> Floki.parse_document!()
      |> elements()
      |> Enum.flat_map(fn node ->
        case Regex.run(re, squish(node)) do
          nil -> []
          [_ | groups] -> groups |> Enum.reject(&(&1 == "")) |> Enum.map(&String.to_integer/1)
        end
      end)
      |> Enum.uniq()

    case values do
      [value] -> value
      other -> flunk("expected one consistent #{label} total, saw #{inspect(other)}")
    end
  end

  defp feed?(html) do
    html
    |> Floki.parse_document!()
    |> elements()
    |> Enum.any?(fn {_t, attrs, _c} -> Enum.any?(attrs, fn {_n, v} -> v in @states end) end)
  end

  defp notice?(html),
    do: Regex.match?(~r/not available yet/i, Floki.text(Floki.parse_document!(html), sep: " "))

  defp assert_public_page(html, user, drops, comments, private) do
    doc = Floki.parse_document!(html)
    text = Floki.text(doc, sep: " ")

    assert text =~ user.name
    assert text =~ user.github_username
    assert Floki.attribute(doc, ~s(img[src="#{user.avatar}"]), "src") != []

    assert Floki.attribute(doc, ~s(a[href="https://github.com/#{user.github_username}"]), "href") !=
             []

    assert total(html, "Drop") == drops
    assert total(html, "Comment") == comments

    for secret <- private do
      refute html =~ secret, "public page leaks private value #{inspect(secret)}"
    end

    refute String.downcase(text) =~ "draft"
    refute String.downcase(text) =~ "bookmark"
    refute text =~ "Saved"
  end

  test "public profile page, identity, privacy, tabs and default", %{conn: conn} do
    owner = user_fixture(%{name: "Ada Owner", email: "ada.owner@private.example"})
    other = user_fixture(%{name: "Bo Author", email: "bo.author@private.example"})
    commenter = user_fixture(%{name: "Cy Commenter", email: "cy.commenter@private.example"})

    owner_drops =
      for n <- 1..3, do: drop_fixture(%Drop{}, owner, %{title: "Owner published piece #{n}"})

    other_drop = drop_fixture(%Drop{}, other, %{title: "Other author piece"})
    doomed = drop_fixture(%Drop{}, owner, %{title: "Owner deleted piece"})

    c1 = comment_fixture(hd(owner_drops), commenter, nil, %{body: "commenter top-level body"})
    _reply = comment_fixture(hd(owner_drops), commenter, c1, %{body: "commenter reply body"})
    _c3 = comment_fixture(other_drop, commenter, nil, %{body: "commenter on other piece"})
    _gone = comment_fixture(doomed, commenter, nil, %{body: "commenter on deleted piece"})
    _o1 = comment_fixture(other_drop, owner, nil, %{body: "owner comment on other piece"})
    _o2 = comment_fixture(hd(owner_drops), owner, nil, %{body: "owner comment on own piece"})
    _o3 = comment_fixture(doomed, owner, nil, %{body: "owner comment on deleted piece"})
    Repo.delete!(doomed)

    {:ok, _} =
      Search.create_search_history(%{
        query: "private-search-zzz",
        results_count: 1,
        user_id: owner.id
      })

    token = Accounts.generate_user_session_token(owner)
    private = [owner.email, "private-search-zzz", Base.encode64(token), Base.url_encode64(token)]

    owner_href = own_profile_href(conn, owner)
    other_href = own_profile_href(conn, other)
    commenter_href = path_for(owner_href, owner, commenter)
    assert owner_href != other_href

    assert String.contains?(owner_href, owner.id) or
             String.contains?(owner_href, owner.github_username)

    viewers = [
      anonymous: conn,
      owner: sign_in_user(conn, owner),
      other_author: sign_in_user(conn, other)
    ]

    for {_who, viewer_conn} <- viewers do
      {:ok, _view, html} = live(viewer_conn, owner_href)
      assert_public_page(html, owner, 3, 2, private)
      assert feed?(html), "default tab for a contributor with Drops must be Drops"
      refute notice?(html)

      drops_href = tab_href(html, owner_href, "Drops")
      comments_href = tab_href(html, owner_href, "Comments")
      assert drops_href != comments_href

      {:ok, _view, drops_html} = live(viewer_conn, drops_href)
      assert feed?(drops_html)
      assert_public_page(drops_html, owner, 3, 2, private)

      {:ok, _view, comments_html} = live(viewer_conn, comments_href)
      assert notice?(comments_html)
      refute feed?(comments_html)
      assert_public_page(comments_html, owner, 3, 2, private)
      refute comments_html =~ "owner comment on other piece"
      refute comments_html =~ "owner comment on deleted piece"

      {:ok, _view, other_html} = live(viewer_conn, other_href)
      assert_public_page(other_html, other, 1, 0, private)

      {:ok, _view, commenter_html} = live(viewer_conn, commenter_href)
      assert_public_page(commenter_html, commenter, 0, 3, private)
      assert notice?(commenter_html), "default tab for a commenter without Drops must be Comments"
      refute feed?(commenter_html)
      refute commenter_html =~ "commenter top-level body"
    end

    # Account menu of a signed-in viewer links to that viewer's own profile; anonymous has none.
    {:ok, _view, anon_home} = live(conn, ~p"/")
    refute Enum.any?(links(anon_home), fn {text, _} -> text =~ "View public profile" end)
    assert URI.parse(other_href).path != URI.parse(owner_href).path

    # Unavailable user: the product's existing not-found page, no header, no totals.
    missing_href =
      owner_href
      |> String.replace(owner.id, Ecto.UUID.generate())
      |> String.replace(owner.github_username, "no-such-user-xyz")

    {404, _headers, body} = assert_error_sent(404, fn -> get(conn, missing_href) end)
    assert body =~ "Page not found"
    refute body =~ owner.name
    refute body =~ "github.com/no-such-user-xyz"
  end
end
