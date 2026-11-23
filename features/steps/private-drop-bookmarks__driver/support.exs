defmodule PrivateDropBookmarks.Support do
  @moduledoc false
  import ExUnit.Assertions
  import Phoenix.LiveViewTest

  def doc(html), do: Floki.parse_document!(html)
  def settle(view), do: render_async(view, 10_000)
  def pad(n), do: n |> Integer.to_string() |> String.pad_leading(4, "0")

  def cards(html), do: html |> doc() |> Floki.find(".drop-card")
  def title_of(card), do: card |> Floki.find("h2") |> Floki.text() |> String.trim()
  def titles(html), do: html |> cards() |> Enum.map(&title_of/1)

  def card(html, title) do
    case Enum.filter(cards(html), &(title_of(&1) == title)) do
      [card | _] -> card
      [] -> flunk("no Drop card titled #{inspect(title)}; cards: #{inspect(titles(html))}")
    end
  end

  # A bookmark control is found by its visible text or accessible name (contains Bookmark) and is a
  # toggle button: it carries the standard aria-pressed state (true = saved, false = not saved).
  def buttons(nodes) do
    nodes
    |> Floki.find("button")
    |> Enum.filter(fn b ->
      label = Floki.text(b) <> " " <> Enum.join(Floki.attribute(b, "aria-label"), " ")
      label =~ ~r/bookmark/i and Floki.attribute(b, "aria-pressed") != []
    end)
  end

  def control!(nodes, label) do
    case buttons(nodes) do
      [button] -> button
      other -> flunk("expected exactly one bookmark control in #{label}, found #{length(other)}")
    end
  end

  def state_of(button) do
    case Floki.attribute(button, "aria-pressed") do
      ["true"] -> "saved"
      ["false"] -> "unsaved"
      other -> flunk("bookmark control aria-pressed must be true or false, got #{inspect(other)}")
    end
  end

  def card_state(html, title), do: html |> card(title) |> control!(title) |> state_of()
  def page_state(html), do: html |> doc() |> control!("the Drop page") |> state_of()
  def in_menu?(html, title), do: buttons(Floki.find(card(html, title), ".menu-panel")) != []

  def click(view, button) do
    case Floki.attribute(button, "id") do
      [id] when id != "" -> view |> element(~s([id="#{id}"])) |> render_click()
      other -> flunk("every bookmark control carries a unique DOM id, got #{inspect(other)}")
    end
  end

  def click_card(view, html, title), do: click(view, control!(card(html, title), title))
  def click_page(view, html), do: click(view, control!(doc(html), "the Drop page"))

  def page_text(html), do: html |> doc() |> Floki.text(sep: " ")

  # The aggregate count is a visible "N bookmark(s)" phrase; nil when none is shown.
  def bookmark_count(html) do
    case Regex.scan(~r/\b(\d+)\s+bookmarks?\b/i, page_text(html)) do
      [] -> nil
      [[_, n]] -> String.to_integer(n)
      other -> flunk("more than one bookmark count phrase: #{inspect(other)}")
    end
  end

  # The Bookmarks link sits right after "My drops" in the account menu and in the My drops header.
  def bookmarks_href(profile_html) do
    hrefs =
      for scope <- ["#slide-menu", "#secondary-nav-links"] do
        links = profile_html |> doc() |> Floki.find("#{scope} a")
        labels = Enum.map(links, &(&1 |> Floki.text() |> String.trim()))
        at = Enum.find_index(labels, &(&1 == "My drops"))
        assert at != nil, "#{scope} has no My drops link: #{inspect(labels)}"
        assert Enum.at(labels, at + 1) == "Bookmarks", "#{scope}: Bookmarks must follow My drops: #{inspect(labels)}"
        [href] = links |> Enum.at(at + 1) |> Floki.attribute("href")
        href
      end

    assert length(Enum.uniq(hrefs)) == 1, "the two Bookmarks links differ: #{inspect(hrefs)}"
    hd(hrefs)
  end

  def count(fun) do
    id = "pdb-count-#{System.unique_integer([:positive])}"
    {:ok, agent} = Agent.start_link(fn -> 0 end)

    :telemetry.attach(
      id,
      [:elixir_drops, :repo, :query],
      fn _e, _m, _meta, _c -> Agent.update(agent, &(&1 + 1)) end,
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
