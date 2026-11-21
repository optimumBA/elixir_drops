Code.require_file("support.exs", __DIR__)

defmodule PublicProfileCommentsTabCorrected.InterruptedTest do
  use ElixirDropsWeb.ConnCase, async: false

  import ElixirDrops.AccountsFixtures
  import Phoenix.LiveViewTest

  alias PublicProfileCommentsTabCorrected.Support, as: S

  defp load_all(view, tries \\ 10) do
    html = render_async(view, 10_000)

    if S.state(html) == "exhausted" or tries == 0 do
      html
    else
      render_hook(view, "load_more", %{})
      load_all(view, tries - 1)
    end
  end

  test "a batch interrupted by switching tabs is never skipped or duplicated", %{conn: conn} do
    author = user_fixture(%{name: "Ina Interrupt"})
    rival = user_fixture(%{name: "Rae Rival"})
    %{entries: entries} = S.build_activity(author, rival, 27)
    all = Enum.map(entries, & &1.token)
    path = S.comments_path(author)

    {:ok, view, _} = live(conn, path)
    first = view |> render_async(10_000) |> S.tokens()
    assert length(first) == 10

    # Hold the second batch, switch to the Drops tab while it is in flight, then release it.
    S.hold(self(), "pct-interrupt-hold", "comments")
    render_hook(view, "load_more", %{})
    assert_receive {:held, task}, 10_000
    render_patch(view, "/u/#{author.id}/drops")
    send(task, :release)
    :telemetry.detach("pct-interrupt-hold")
    render_patch(view, path)

    # Back on Comments: the first batch is intact; the interrupted batch is either appended whole
    # or still to be requested, never partly present.
    back = view |> render_async(10_000) |> S.tokens()
    assert Enum.take(back, 10) == first
    assert length(back) in [10, 20], "interrupted batch left #{length(back)} entries"
    assert back == Enum.uniq(back)

    # Continuing yields every entry exactly once.
    html = load_all(view)
    final = S.tokens(html)
    assert S.state(html) == "exhausted"
    assert Enum.sort(final) == Enum.sort(all)
    S.assert_feed(final, entries)
  end
end
