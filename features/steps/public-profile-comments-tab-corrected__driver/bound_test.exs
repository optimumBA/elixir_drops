Code.require_file("support.exs", __DIR__)

defmodule PublicProfileCommentsTabCorrected.BoundTest do
  use ElixirDropsWeb.ConnCase, async: false

  import ElixirDrops.AccountsFixtures
  import Phoenix.LiveViewTest

  alias PublicProfileCommentsTabCorrected.Support, as: S

  # The upper bound is the work observed for the smaller history: opening the tab and every
  # further batch for 100 entries may not cost more queries than for 15 entries, and a batch
  # never costs one query per entry it adds.
  defp measure(conn, size) do
    author = user_fixture(%{name: "Bound Author #{size}"})
    rival = user_fixture(%{name: "Bound Rival #{size}"})
    S.build_activity(author, rival, size)
    path = S.comments_path(author)

    {view, open} =
      S.count(fn ->
        {:ok, v, _} = live(conn, path)
        render_async(v, 10_000)
        v
      end)

    {batches, _} =
      Enum.map_reduce(1..div(size - 1, 10), length(S.tokens(render(view))), fn _, before ->
        {html, n} =
          S.count(fn ->
            render_hook(view, "load_more", %{})
            render_async(view, 10_000)
          end)

        loaded = length(S.tokens(html))
        {{n, loaded - before}, loaded}
      end)

    %{open: open, batches: batches}
  end

  test "query count per batch stays within the same bound for 15 and 100 entries", %{conn: conn} do
    small = measure(conn, 15)
    large = measure(conn, 100)

    small_bound = small.batches |> Enum.map(&elem(&1, 0)) |> Enum.max()
    assert Enum.all?(small.batches, fn {_q, added} -> added > 0 end), "small history loaded no entries"
    assert Enum.all?(large.batches, fn {_q, added} -> added > 0 end), "large history stopped loading"

    assert large.open <= small.open, "opening: #{large.open} queries for 100 entries vs #{small.open} for 15"

    assert Enum.all?(large.batches, fn {q, _added} -> q <= small_bound end),
           "batches for 100 entries: #{inspect(large.batches)}; bound from 15 entries: #{small_bound}"

    assert Enum.all?(large.batches ++ small.batches, fn {q, added} -> q < added end),
           "a batch costs one query per entry: #{inspect(large.batches ++ small.batches)}"
  end
end
