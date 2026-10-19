defmodule ElixirDropsWeb.Features.DnsimpleSponsorTest do
  use ElixirDropsWeb.FeatureCase, async: false

  alias ElixirDrops.Drops.Drop
  alias PhoenixTest.Playwright.Connection
  alias PhoenixTest.Playwright.Frame
  alias PhoenixTest.Playwright.Page

  @moduletag :feature

  @card "#dnsimple-homepage-feed"

  # Realistic organic cards. With DNSIMPLE_ORGANIC_SCREENSHOT_DIR set (a folder
  # of existing Drop code screenshots) cards carry real images, so geometry is
  # judged against real heights instead of empty fixtures.
  @organic [
    {"String.downcase/1 can turn garbage into valid input: use :ascii",
     "String.downcase/1 and String.upcase/1 follow Unicode case mapping. That is usually useful for human text, but can be unsafe for identifiers."},
    {"Choosing Elixir tools with elixir.menu",
     "elixir.menu is a guide to choosing tools for Elixir applications, from command-line utilities to Phoenix web apps."},
    {"Admit when you’re wrong",
     "Use the Campfire benchmarks as an opportunity to look at the state of the tools we build."},
    {"Trapping exits so terminate/2 actually runs",
     "A GenServer that flushes buffered work in terminate/2 needs to trap exits before its supervisor shuts it down."}
  ]

  @layout_js """
    (() => {
      const items = [...document.querySelectorAll('#drops .masonry-item')];
      const sponsor = document.querySelector('#sponsor-dnsimple-homepage-feed');
      const organic = items.find((i) => i !== sponsor);
      const rects = items.map((i) => ({id: i.id, r: i.getBoundingClientRect()}));
      const ready = document.querySelector('#drops').classList.contains('masonry-ready');
      const visual = [...rects].sort((a, b) =>
        Math.round(a.r.top) - Math.round(b.r.top) || a.r.left - b.r.left).map((x) => x.id);
      const a = document.querySelector('#dnsimple-homepage-feed');
      const style = (el) => {
        const c = getComputedStyle(el);
        return {bg: c.backgroundColor, border: c.borderTopColor, radius: c.borderTopLeftRadius};
      };
      return {
        ready,
        viewportWidth: window.innerWidth,
        pageWidth: document.documentElement.scrollWidth,
        settled: Number(getComputedStyle(document.querySelector("#drops")).opacity) === 1 && [...document.querySelectorAll(".drop-card")].every((el) => Number(getComputedStyle(el).opacity) === 1),
        domIds: items.map((i) => i.id),
        visualIds: visual,
        cards: document.querySelectorAll('#dnsimple-homepage-feed').length,
        sponsorWidth: sponsor ? sponsor.getBoundingClientRect().width : 0,
        organicWidth: organic ? organic.getBoundingClientRect().width : 0,
        href: a && a.getAttribute('href'),
        rel: a && a.getAttribute('rel'),
        text: a && a.innerText,
        sponsorStyle: sponsor && style(sponsor.querySelector('.drop-card')),
        organicStyle: organic && style(organic.querySelector('.drop-card')),
        links: sponsor ? sponsor.querySelectorAll('a').length : 0,
      };
    })()
  """

  setup do
    user = user_fixture()

    for {{title, body}, n} <- Enum.with_index(@organic, 1) do
      drop_fixture(%Drop{}, user, %{
        title: "#{title} #{n}",
        body: body,
        screenshot: %{internal_url: screenshot_data_uri(n), meta_url: nil, status: :completed}
      })
    end

    :ok
  end

  for {name, width, height} <- [{"mobile", 390, 844}, {"desktop", 1280, 900}] do
    @name name
    @width width
    @height height

    test "second masonry card, native appearance at #{width}px", %{conn: conn} do
      session =
        conn
        |> visit("/")
        |> viewport(@width, @height)
        |> visit("/")

      assert_has(session, @card)

      layout = wait_for_layout(session)

      assert Enum.at(layout["domIds"], 1) == "sponsor-dnsimple-homepage-feed"
      assert Enum.count(layout["domIds"], &(&1 == "sponsor-dnsimple-homepage-feed")) == 1
      assert layout["cards"] == 1
      assert layout["viewportWidth"] == @width
      assert layout["pageWidth"] <= @width

      # Visual order (top, then left) matches stream order, so the sponsor is
      # the second card on screen, with the organic card's width.
      assert Enum.at(layout["visualIds"], 1) == "sponsor-dnsimple-homepage-feed"
      assert_in_delta layout["sponsorWidth"], layout["organicWidth"], 1.0

      assert layout["href"] == "https://blog.dnsimple.com/2026/10/making-dns-erlang-fast/"
      assert layout["rel"] == "sponsored noopener"
      assert layout["text"] =~ "Sponsored"
      assert layout["text"] =~ "DNSimple · Sponsor"
      assert layout["text"] =~ "Read the article"

      # Quiet native treatment: same fill, border colour and radius as an
      # organic card; one link only.
      assert layout["sponsorStyle"] == layout["organicStyle"]
      assert layout["links"] == 1

      if dir = System.get_env("DNSIMPLE_SCREENSHOT_DIR") do
        unwrap(session, fn %{page_id: page_id} ->
          File.mkdir_p!(dir)
          {:ok, img} = Page.screenshot(page_id, full_page: true)
          file = Path.join(dir, "homepage-#{@name}-#{@width}.png")
          File.write!(file, Base.decode64!(img))
        end)
      end
    end
  end

  test "search hides the card and clearing restores it second",
       %{conn: conn} do
    session =
      conn
      |> visit("/")
      |> viewport(390, 844)
      |> visit("/")

    assert_has(session, @card)
    wait_for_layout(session)

    # Same LiveView process throughout: events go through the live socket.
    push_event(session, "search_submit", %{query: "ascii"})
    refute_has(session, @card)
    assert_has(session, "#drops .masonry-item")
    assert layout_of(session)["cards"] == 0

    push_event(session, "clear_search", %{})
    assert_has(session, @card)
    layout = wait_for_layout(session)
    assert layout["cards"] == 1
    assert Enum.at(layout["domIds"], 1) == "sponsor-dnsimple-homepage-feed"
    assert length(layout["domIds"]) == 5
    assert Enum.at(layout["visualIds"], 1) == "sponsor-dnsimple-homepage-feed"

    push_event(session, "refresh_drops", %{})
    push_event(session, "search_submit", %{query: "ascii"})
    refute_has(session, @card)
    push_event(session, "clear_search", %{})
    assert_has(session, @card)
    assert wait_for_layout(session)["cards"] == 1
  end

  defp screenshot_data_uri(n) do
    with dir when is_binary(dir) <- System.get_env("DNSIMPLE_ORGANIC_SCREENSHOT_DIR"),
         [_ | _] = files <-
           dir
           |> Path.join("*.png")
           |> Path.wildcard()
           |> Enum.sort(),
         {:ok, bin} <-
           files
           |> Enum.at(rem(n - 1, length(files)))
           |> File.read() do
      "data:image/png;base64," <> Base.encode64(bin)
    else
      _unavailable_image -> nil
    end
  end

  defp layout_of(session), do: unwrap_value(session, @layout_js)

  defp push_event(session, event, payload) do
    json = Jason.encode!(payload)

    unwrap_value(session, """
      (() => {
        const root = document.querySelector('[data-phx-main]');
        return window.liveSocket.getViewByEl(root)
          .pushHookEvent(root, null, '#{event}', #{json}).then(() => true);
      })()
    """)

    # Allow the patch and masonry re-layout to settle.
    Process.sleep(300)
    session
  end

  defp wait_for_layout(session, retries \\ 40) do
    layout =
      unwrap_value(session, @layout_js)

    cond do
      layout["ready"] and layout["settled"] and
          layout["pageWidth"] <= layout["viewportWidth"] ->
        layout

      retries == 0 ->
        layout

      true ->
        Process.sleep(100)
        wait_for_layout(session, retries - 1)
    end
  end

  defp unwrap_value(session, js) do
    test_pid = self()

    unwrap(session, fn %{frame_id: frame_id} ->
      send(test_pid, {:value, Frame.evaluate(frame_id, js)})
    end)

    receive do
      {:value, value} -> value
    after
      5000 -> flunk("no browser value")
    end
  end

  defp viewport(session, width, height) do
    unwrap(session, fn %{page_id: page_id} ->
      response =
        Connection.post(
          guid: page_id,
          method: :set_viewport_size,
          params: %{viewport_size: %{width: width, height: height}}
        )

      refute Map.has_key?(response, :error)
    end)

    session
  end
end
