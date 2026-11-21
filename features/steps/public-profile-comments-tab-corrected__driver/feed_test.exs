Code.require_file("support.exs", __DIR__)

defmodule PublicProfileCommentsTabCorrected.FeedTest do
  use ElixirDropsWeb.ConnCase, async: false

  import Ecto.Query
  import ElixirDrops.AccountsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Comments.Comment
  alias ElixirDrops.Repo
  alias PublicProfileCommentsTabCorrected.Support, as: S

  # The Retry control is the one button of the feed that is not an expand/collapse toggle.
  @retry "#profile-comments button:not([aria-expanded])"

  defp load_all(view, tries \\ 10) do
    html = render_async(view, 10_000)

    if S.state(html) == "exhausted" or tries == 0 do
      html
    else
      render_hook(view, "load_more", %{})
      load_all(view, tries - 1)
    end
  end

  test "comments feed lists only the contributor's comments and replies in tied-timestamp batches with every state",
       %{conn: conn} do
    author = user_fixture(%{name: "Ada Author"})
    rival = user_fixture(%{name: "Rae Rival"})
    nobody = user_fixture(%{name: "Nia Nocomments"})

    %{entries: entries, drops: drops} = S.build_activity(author, rival, 27)
    S.rival_comments(rival, drops, 6)
    all = Enum.map(entries, & &1.token)
    path = S.comments_path(author)

    # First batch: ten newest entries, idle, nothing of the rival, total matches, no placeholder.
    {:ok, view, _} = live(conn, path)
    html = render_async(view, 10_000)
    first = S.tokens(html)
    assert length(first) == 10
    assert S.state(html) == "idle"
    refute html =~ "RIV-"
    refute S.text(html) =~ ~r/not available yet/i
    assert S.total_text(html) =~ "27 Comment"
    S.assert_feed(first, entries)

    # Loading: a held continuation batch keeps the loaded entries and shows loading.
    S.hold(self(), "pct-hold", "comments")
    render_hook(view, "load_more", %{})
    assert_receive {:held, task}, 10_000
    loading = render(view)
    assert S.state(loading) == "loading"
    assert S.tokens(loading) == first
    send(task, :release)
    :telemetry.detach("pct-hold")
    second = render_async(view, 10_000)
    assert length(S.tokens(second)) == 20
    assert Enum.take(S.tokens(second), 10) == first
    assert S.state(second) == "idle"

    # Tab switching keeps the loaded entries: Drops and back to Comments still lists the same 20.
    render_patch(view, "/u/#{author.id}/drops")
    render_patch(view, path)
    back = render_async(view, 10_000)
    assert Enum.take(S.tokens(back), 20) == S.tokens(second)
    assert S.state(back) == "idle"

    # Retry: a failed batch keeps entries, shows retry, and the same batch is requested again.
    Repo.query!("ALTER TABLE comments RENAME TO comments_failed_by_test")
    render_hook(view, "load_more", %{})
    failed = render_async(view, 10_000)
    Repo.query!("ALTER TABLE comments_failed_by_test RENAME TO comments")
    assert S.state(failed) == "retry"
    assert S.tokens(failed) == S.tokens(second)
    assert has_element?(view, @retry)
    view |> element(@retry) |> render_click()
    done = render_async(view, 10_000)
    final = S.tokens(done)
    assert S.state(done) == "exhausted"
    assert Enum.sort(final) == Enum.sort(all)
    S.assert_feed(final, entries)
    assert Enum.take(final, 20) == S.tokens(second)

    # Exhausted: no further comments query.
    {_, queries} =
      S.count(
        fn ->
          render_hook(view, "load_more", %{})
          render_async(view, 10_000)
        end,
        "comments"
      )

    assert queries == 0

    # A signed-in visitor sees the same first batch as the guest.
    {:ok, view2, _} = live(sign_in_user(conn, rival), path)
    assert S.tokens(render_async(view2, 10_000)) == first

    # Empty: a contributor without comments, and never for one with comments.
    {:ok, view3, _} = live(conn, S.comments_path(nobody))
    empty = render_async(view3, 10_000)
    assert S.state(empty) == "empty"
    assert S.tokens(empty) == []
    assert String.trim(S.text(empty)) != ""
    refute S.text(empty) =~ ~r/not available yet/i

    # Deletion follows the real cascade: a deleted Drop and a deleted parent remove their comments.
    deleted_drop = hd(drops)
    reply = Enum.find(entries, &(&1.parent && &1.drop.id != deleted_drop.id))
    assert reply, "fixture must hold a reply on a Drop other than the deleted one"
    Repo.delete!(reply.parent)
    Repo.delete!(deleted_drop)
    remaining = Repo.all(from c in Comment, where: c.user_id == ^author.id, select: c.id) |> MapSet.new()
    expected = for e <- entries, MapSet.member?(remaining, e.id), do: e.token
    assert expected != [] and length(expected) < 27
    refute reply.token in expected

    {:ok, view4, _} = live(conn, path)
    html4 = load_all(view4)
    assert Enum.sort(S.tokens(html4)) == Enum.sort(expected)
    assert S.total_text(html4) =~ "#{length(expected)} Comment"
  end
end
