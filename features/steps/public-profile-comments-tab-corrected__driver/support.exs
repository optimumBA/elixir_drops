defmodule PublicProfileCommentsTabCorrected.Support do
  @moduledoc false
  import ExUnit.Assertions
  import Ecto.Query
  import ElixirDrops.CommentsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Comments.Comment
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Repo

  @states ~w(idle loading retry empty exhausted)
  @base ~N[2025-06-01 12:00:00]

  def pad(n), do: n |> Integer.to_string() |> String.pad_leading(4, "0")
  def comments_path(user), do: "/u/#{user.id}/comments"

  def set_inserted_at(comment, ts) do
    Repo.update_all(from(c in Comment, where: c.id == ^comment.id), set: [inserted_at: ts])
  end

  # `count` entries by `author`: every third is a reply to a rival comment. Entry i is older as i
  # grows, in groups of four that share one timestamp (ties). Bodies start with a unique token.
  # Top-level comments cycle through the Drops by i; replies cycle through them by i / 3, so every
  # Drop (with 3 or more Drops) carries both comments and replies.
  def build_activity(author, rival, count, drop_count \\ 3) do
    drops = for k <- 1..drop_count, do: drop_fixture(%Drop{}, rival, %{title: "Rival Drop #{k}"})

    entries =
      for i <- 1..count do
        {parent, token, comment, drop} =
          if rem(i, 3) == 0 do
            drop = Enum.at(drops, rem(div(i, 3), drop_count))
            parent = comment_fixture(drop, rival, nil, %{body: "PAR-#{pad(i)} parent text"})
            token = "RPL-#{pad(i)}"
            {parent, token, comment_fixture(drop, author, parent, %{body: "#{token} reply text"}), drop}
          else
            drop = Enum.at(drops, rem(i, drop_count))
            token = "CMT-#{pad(i)}"
            {nil, token, comment_fixture(drop, author, nil, %{body: "#{token} comment text"}), drop}
          end

        ts = NaiveDateTime.add(@base, -div(i - 1, 4) * 60)
        set_inserted_at(comment, ts)
        %{token: token, id: comment.id, ts: ts, parent: parent, drop: drop}
      end

    %{entries: entries, drops: drops}
  end

  def rival_comments(rival, drops, n) do
    for i <- 1..n do
      comment_fixture(Enum.at(drops, rem(i, length(drops))), rival, nil, %{body: "RIV-#{pad(i)} rival text"})
    end
  end

  def container(html) do
    case html |> Floki.parse_document!() |> Floki.find("#profile-comments") do
      [node | _] -> node
      [] -> flunk("no #profile-comments container rendered")
    end
  end

  def text(html), do: html |> container() |> Floki.text(sep: " ")

  def tokens(html), do: ~r/\b(?:CMT|RPL)-\d{4}\b/ |> Regex.scan(text(html)) |> List.flatten()

  defp elements(nodes) when is_list(nodes), do: Enum.flat_map(nodes, &elements/1)
  defp elements({tag, attrs, children}) when is_binary(tag), do: [{tag, attrs, children} | elements(children)]
  defp elements(_other), do: []

  # Exactly one rendered attribute value inside the Comments container is a feed state word.
  def state(html) do
    values =
      for {_t, attrs, _c} <- elements([container(html)]), {_n, v} <- attrs, v in @states, do: v

    case values do
      [value] -> value
      other -> flunk("expected exactly one feed state attribute value, got #{inspect(other)}")
    end
  end

  def total_text(html) do
    html |> Floki.parse_document!() |> Floki.find("#profile-comments-total") |> Floki.text() |> String.trim()
  end

  def assert_feed(tokens, entries) do
    ts = Map.new(entries, &{&1.token, &1.ts})
    assert tokens == Enum.uniq(tokens), "duplicate entries: #{inspect(tokens -- Enum.uniq(tokens))}"
    stamps = Enum.map(tokens, &Map.fetch!(ts, &1))
    assert stamps == Enum.sort(stamps, {:desc, NaiveDateTime}), "entries are not newest first"
  end

  def hold(test_pid, id, source) do
    :telemetry.attach(
      id,
      [:elixir_drops, :repo, :query],
      fn _event, _measure, meta, _config ->
        if meta.source == source and self() != test_pid do
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

  # Runs `fun` and returns {result, number of repo queries, optionally only of one source}.
  def count(fun, source \\ nil) do
    id = "pct-count-#{System.unique_integer([:positive])}"
    {:ok, agent} = Agent.start_link(fn -> 0 end)

    :telemetry.attach(
      id,
      [:elixir_drops, :repo, :query],
      fn _e, _m, meta, _c ->
        if is_nil(source) or meta.source == source, do: Agent.update(agent, &(&1 + 1))
      end,
      nil
    )

    try do
      result = fun.()
      {result, Agent.get(agent, & &1)}
    after
      :telemetry.detach(id)
    end
  end
end
