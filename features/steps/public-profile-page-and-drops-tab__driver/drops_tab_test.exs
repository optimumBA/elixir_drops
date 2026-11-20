defmodule PublicProfilePageAndDropsTab.DropsTabTest do
  use ElixirDropsWeb.ConnCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Repo

  @states ~w(idle loading retry empty exhausted)

  defp elements(nodes) when is_list(nodes), do: Enum.flat_map(nodes, &elements/1)

  defp elements({tag, attrs, children}) when is_binary(tag),
    do: [{tag, attrs, children} | elements(children)]

  defp elements(_other), do: []

  defp links(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("a, button")
    |> Enum.map(fn a ->
      {a |> Floki.text(sep: " ") |> String.split() |> Enum.join(" "),
       List.first(Floki.attribute(a, "href"))}
    end)
  end

  defp profile_href(conn, user) do
    {:ok, _view, html} = live(sign_in_user(conn, user), ~p"/")

    case Enum.find(links(html), fn {text, _} -> text =~ "View public profile" end) do
      {_text, href} when is_binary(href) -> href
      nil -> flunk("account menu has no View public profile link")
    end
  end

  defp drops_tab_href(html, base) do
    base_path = URI.parse(base).path

    case Enum.find(links(html), fn {text, href} ->
           path = href && URI.parse(href).path

           Regex.match?(~r/^Drops(\s+\d+)?$/, text) and
             (path == base_path or String.starts_with?(path || "", base_path <> "/"))
         end) do
      {_t, href} -> href
      nil -> flunk("no Drops tab link")
    end
  end

  # The feed container exposes its state as the one attribute whose value is one of
  # the five state words; exactly one such attribute must be rendered.
  defp state(html) do
    values =
      html
      |> Floki.parse_document!()
      |> elements()
      |> Enum.flat_map(fn {_t, attrs, _c} -> for {_n, v} <- attrs, v in @states, do: v end)

    case values do
      [value] -> value
      other -> flunk("expected exactly one feed state attribute value, got #{inspect(other)}")
    end
  end

  defp listed(html, drops), do: Enum.filter(drops, &(html =~ ~s(id="drop-#{&1.id}")))

  defp occurrences(html, drop), do: length(Regex.scan(~r/id="drop-#{drop.id}"/, html))

  defp batch_size(view), do: :sys.get_state(view.pid).socket.assigns.batch_size

  defp hold_batch_queries(test_pid, id) do
    :telemetry.attach(
      id,
      [:elixir_drops, :repo, :query],
      fn _event, _measure, meta, _config ->
        if meta.source == "drops" and self() != test_pid do
          send(test_pid, {:held, self()})

          receive do
            :release -> :ok
          after
            10_000 -> :ok
          end
        end
      end,
      nil
    )
  end

  defp count_batch_queries(test_pid, id) do
    :telemetry.attach(
      id,
      [:elixir_drops, :repo, :query],
      fn _event, _measure, meta, _config ->
        if meta.source == "drops" and self() != test_pid,
          do: send(test_pid, {:drops_query, self()})
      end,
      nil
    )
  end

  test "drops tab lists published drops and exposes the four feed states", %{conn: conn} do
    author = user_fixture(%{name: "Ada Author"})
    rival = user_fixture(%{name: "Rae Rival"})
    nobody = user_fixture(%{name: "Nia Nodrops"})

    {:ok, my_drops_view, _} = live(sign_in_user(conn, author), ~p"/profile")
    bs = batch_size(my_drops_view)
    total = 2 * bs + 3

    drops =
      for n <- 1..total do
        title = if n in [5, 9], do: "needle published #{n}", else: "Author published #{n}"
        drop = drop_fixture(%Drop{}, author, %{title: title})
        update_drop_inserted_at(drop, -n * 60)
      end

    rival_drops =
      for n <- 1..3 do
        drop_fixture(%Drop{}, rival, %{title: "needle rival #{n}"})
      end

    href = profile_href(conn, author)
    nobody_href = profile_href(conn, nobody)

    # Initial batch: first batch only, newest first, idle, no Previous/Next, no rival drops.
    {:ok, view, html} = live(conn, href)
    assert batch_size(view) == bs
    assert state(html) == "idle"
    assert listed(html, drops) == Enum.take(drops, bs)
    assert listed(html, rival_drops) == []

    refute Enum.any?(links(html), fn {text, _} -> text in ["Previous", "Next"] end)

    # Loading: held batch request.
    test_pid = self()
    hold_batch_queries(test_pid, "profile-hold")
    loading_html = render_hook(view, "load_more", %{})
    assert_receive {:held, task}, 10_000
    assert state(loading_html) == "loading"
    assert state(render(view)) == "loading"
    send(task, :release)
    :telemetry.detach("profile-hold")
    done_html = render_async(view, 10_000)
    assert state(done_html) != "loading"
    assert state(done_html) == "idle"
    assert listed(done_html, drops) == Enum.take(drops, 2 * bs)

    # Retry: one failed batch request, then the control loads that same batch.
    Repo.query!("ALTER TABLE drops RENAME TO drops_failed_by_test")
    render_hook(view, "load_more", %{})
    failed_html = render_async(view, 10_000)
    Repo.query!("ALTER TABLE drops_failed_by_test RENAME TO drops")
    assert state(failed_html) == "retry"
    assert listed(failed_html, drops) == Enum.take(drops, 2 * bs)
    assert has_element?(view, "button", "Retry")

    view |> element("button", "Retry") |> render_click()
    retried_html = render_async(view, 10_000)
    assert state(retried_html) != "retry"
    assert listed(retried_html, drops) == drops
    assert Enum.all?(drops, &(occurrences(retried_html, &1) == 1))
    assert state(retried_html) == "exhausted"

    # Exhausted: no further request is made.
    count_batch_queries(test_pid, "profile-count")
    render_hook(view, "load_more", %{})
    final_html = render_async(view, 10_000)
    :telemetry.detach("profile-count")
    refute_received {:drops_query, _}
    assert state(final_html) == "exhausted"
    assert listed(final_html, drops) == drops
    assert length(drops) == total

    # Search is limited to this author.
    {:ok, _search_view, search_html} = live(conn, href <> "?q=needle")

    assert Enum.map(listed(search_html, drops), & &1.title) |> Enum.sort() ==
             ["needle published 5", "needle published 9"]

    assert listed(search_html, rival_drops) == []

    # Empty: no match, and an author without published drops.
    {:ok, _v, nomatch_html} = live(conn, href <> "?q=zzzznomatchzzzz")
    assert state(nomatch_html) == "empty"

    {:ok, _v, nobody_default} = live(conn, nobody_href)
    {:ok, _v, nobody_drops} = live(conn, drops_tab_href(nobody_default, nobody_href))
    assert state(nobody_drops) == "empty"
  end
end
