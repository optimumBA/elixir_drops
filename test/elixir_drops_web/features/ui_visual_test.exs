defmodule ElixirDropsWeb.Features.UiVisualTest do
  @moduledoc """
  Browser regression tests for the shared UI styling (docs/ui-design-system.md).

  Opens the feed, a Drop page, the Drop card menu, the account menu, the
  notification panel, search suggestions and the 404 page in a real browser at
  desktop (1280px), phone (390px) and zoom (320px, the width a 400% browser zoom
  gives a 1280px window) viewports, signed out and signed in, and asserts: no
  horizontal overflow, menus inside the viewport, computed contrast against the
  design-system targets, JetBrains Mono on code, keyboard focus indicators,
  reduced-motion emulation and HTTP 404.

  Screenshots of every checked state are kept under
  `tmp/ui-visual/<git revision>/` so a run is tied to the source revision.

  Run with `FEATURE_TESTS=true mix test test/elixir_drops_web/features/ui_visual_test.exs --only feature`.
  """

  use ElixirDropsWeb.FeatureCase, async: true

  import ElixirDrops.FeatureHelpers

  alias ElixirDrops.Drops.Drop
  alias PhoenixTest.Playwright.Connection
  alias PhoenixTest.Playwright.Frame

  @moduletag :feature

  @viewports [desktop: {1280, 800}, phone: {390, 844}, zoom: {320, 256}]

  @body """
  Reading text before the code.

  ```elixir
  def example(data) do
    case data do
      {:ok, value} -> value
      _ -> :error
    end
  end
  ```
  """

  # Browser-side helpers shared by every check: contrast against the effective
  # background (any CSS color, including oklch, is converted through a canvas),
  # rect containment and horizontal overflow.
  @helpers """
  const rgba = (css) => {
    const c = document.createElement('canvas'); c.width = c.height = 1;
    const x = c.getContext('2d', { willReadFrequently: true });
    x.clearRect(0, 0, 1, 1); x.fillStyle = css; x.fillRect(0, 0, 1, 1);
    const d = x.getImageData(0, 0, 1, 1).data;
    return [d[0], d[1], d[2], d[3] / 255];
  };
  const lin = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); };
  const lum = (c) => 0.2126 * lin(c[0]) + 0.7152 * lin(c[1]) + 0.0722 * lin(c[2]);
  const ratio = (a, b) => { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); };
  const over = (top, bottom) => [0, 1, 2].map((i) => top[i] * top[3] + bottom[i] * (1 - top[3])).concat([1]);
  const backdrop = (el) => {
    const layers = [];
    for (let n = el; n; n = n.parentElement) {
      const bg = rgba(getComputedStyle(n).backgroundColor);
      if (bg[3] > 0) layers.push(bg);
      if (bg[3] === 1) break;
    }
    return layers.reduceRight((acc, l) => over(l, acc), [255, 255, 255, 1]);
  };
  const textContrast = (el) => {
    const bg = backdrop(el);
    const fg = over(rgba(getComputedStyle(el).color), bg);
    return ratio(fg, bg);
  };
  const noOverflow = () => document.documentElement.scrollWidth <= window.innerWidth
    ? null : 'horizontal overflow: scrollWidth ' + document.documentElement.scrollWidth + ' > ' + window.innerWidth;
  const inside = (el, vertical) => {
    const r = el.getBoundingClientRect();
    if (r.width === 0 || r.height === 0) return 'not rendered';
    if (r.left < -0.5 || r.right > window.innerWidth + 0.5) return 'outside horizontally ' + r.left + '..' + r.right + ' of ' + window.innerWidth;
    if (vertical && (r.top < -0.5 || r.bottom > window.innerHeight + 0.5)) return 'outside vertically ' + r.top + '..' + r.bottom + ' of ' + window.innerHeight;
    return null;
  };
  const visible = (el) => !!el && getComputedStyle(el).display !== 'none' && el.getBoundingClientRect().width > 0;
  """

  defp shot(session, name) do
    dir = Path.join(["tmp", "ui-visual", revision()])
    File.mkdir_p!(dir)

    unwrap(session, fn %{page_id: page_id} ->
      %{result: %{binary: binary}} =
        Connection.post(
          [guid: page_id, method: :screenshot, params: %{full_page: false}],
          15_000
        )

      path = Path.join(dir, "#{name}.png")
      png = Base.decode64!(binary)
      File.write!(path, png)
    end)

    session
  end

  defp revision do
    case System.cmd("git", ["rev-parse", "--short", "HEAD"], stderr_to_stdout: true, env: []) do
      {rev, 0} -> String.trim(rev)
      _failure -> "unknown-revision"
    end
  end

  # Runs `js` in the page, polling up to three seconds until it returns "ok".
  defp assert_page(session, label, js) do
    unwrap(session, fn %{frame_id: frame_id} ->
      script = """
      (async () => {
        #{@helpers}
        const run = async () => { #{js} };
        let result = await run();
        for (let i = 0; i < 60 && result !== 'ok'; i++) {
          await new Promise((resolve) => setTimeout(resolve, 50));
          result = await run();
        }
        return result;
      })()
      """

      result = Frame.evaluate(frame_id, script, timeout: 10_000)
      assert result == "ok", "#{label}: #{inspect(result)}"
    end)
  end

  defp click_selector(session, selector) do
    unwrap(session, fn %{frame_id: frame_id} ->
      {:ok, _result} = Frame.click(frame_id, selector, %{timeout: 5_000})
    end)
  end

  # Presses Tab until the focused element matches `selector` (at most 40 presses).
  defp tab_until(session, selector) do
    unwrap(session, fn %{frame_id: frame_id} ->
      assert tab_to(frame_id, selector, 40), "Tab never reached #{selector}"
    end)
  end

  defp tab_to(_frame_id, _selector, 0), do: false

  defp tab_to(frame_id, selector, presses_left) do
    {:ok, _result} = Frame.press(frame_id, "body", "Tab")

    Frame.evaluate(frame_id, "document.activeElement.matches(#{inspect(selector)})") ||
      tab_to(frame_id, selector, presses_left - 1)
  end

  # A real pointer hover (not a synthetic event), so :hover styles apply.
  defp hover_selector(session, selector) do
    unwrap(session, fn %{frame_id: frame_id} ->
      response =
        Connection.post(
          [guid: frame_id, method: :hover, params: %{selector: selector, strict: true}],
          5_000
        )

      refute match?(%{error: _}, response), inspect(response)
    end)
  end

  defp resize(session, {width, height}), do: resize_window(session, width, height)

  defp emulate_reduced_motion(session) do
    unwrap(session, fn %{page_id: page_id} ->
      response =
        Connection.post(
          guid: page_id,
          method: :emulate_media,
          params: %{reduced_motion: "reduce"}
        )

      refute match?(%{error: _}, response), inspect(response)
    end)
  end

  defp create_content do
    author = user_fixture(%{github_username: "visual_author"})
    drop = drop_fixture(%Drop{}, author, %{title: "Visual check drop", body: @body})
    %{author: author, drop: drop}
  end

  for {name, size} <- @viewports do
    describe "#{name} viewport, signed out" do
      @describetag error_path_exemption:
                     "Authorization refusals are unchanged and covered by visitor_authentication_test."
      setup do
        create_content()
      end

      test "feed: single h1, h2 cards, no overflow, readable text (#{name})", %{conn: conn} do
        conn
        |> visit("/")
        |> resize(unquote(Macro.escape(size)))
        |> wait_for_element(".drop-card h2 a")
        |> assert_page("feed structure", """
        if (document.querySelectorAll('h1').length !== 1) return 'h1 count ' + document.querySelectorAll('h1').length;
        if (document.querySelector('h3.drop-title')) return 'a card title is still an h3';
        if (!document.querySelector('h2.drop-title')) return 'no h2.drop-title';
        const levels = [...document.querySelectorAll('h1, h2, h3, h4, h5, h6')].map((h) => Number(h.tagName[1]));
        for (let i = 1; i < levels.length; i++) if (levels[i] - levels[i - 1] > 1) return 'skipped heading level in ' + levels;
        return noOverflow() || 'ok';
        """)
        |> assert_page("feed text contrast >= 4.5:1", """
        for (const sel of ['.drop-title a', '.drop-body', '.drop-meta p', '.drop-meta div']) {
          for (const el of document.querySelectorAll(sel)) {
            const r = textContrast(el);
            if (r < 4.5) return sel + ' contrast ' + r.toFixed(2);
          }
        }
        return 'ok';
        """)
        |> shot("feed-#{unquote(name)}-signed-out")
      end

      test "feed: keyboard focus shows a 3:1 outline on the card link (#{name})", %{conn: conn} do
        conn
        |> visit("/")
        |> resize(unquote(Macro.escape(size)))
        |> wait_for_element(".drop-card h2 a")
        |> tab_until(".drop-card h2 a")
        |> assert_page("keyboard focus indicator", """
        const target = document.activeElement;
        const s = getComputedStyle(target);
        if (!target.matches('.drop-card h2 a')) return 'focus is on ' + target.tagName;
        if (!target.matches(':focus-visible')) return 'link not :focus-visible';
        if (s.outlineStyle === 'none' || parseFloat(s.outlineWidth) < 2) return 'no visible outline: ' + s.outlineStyle + ' ' + s.outlineWidth;
        const r = ratio(rgba(s.outlineColor), [255, 255, 255, 1]);
        return r >= 3 ? 'ok' : 'focus outline contrast ' + r.toFixed(2);
        """)
        |> shot("feed-#{unquote(name)}-focus")
      end

      test "drop page: h1, comments h2, JetBrains Mono on the code surface (#{name})", %{
        conn: conn,
        drop: drop
      } do
        conn
        |> visit("/d/#{drop.short_id}")
        |> resize(unquote(Macro.escape(size)))
        |> wait_for_element("#drop-body pre")
        |> assert_page("drop structure", """
        if (document.querySelectorAll('h1').length !== 1) return 'h1 count';
        const comments = [...document.querySelectorAll('h2')].find((h) => h.textContent.includes('Comments'));
        if (!comments) return 'comments heading is not an h2';
        if (document.querySelector('h3.text-lg')) return 'comments heading is still an h3';
        return noOverflow() || 'ok';
        """)
        |> assert_page("code typography", """
        const pre = document.querySelector('#drop-body pre');
        const code = pre.querySelector('code');
        if (!/JetBrains Mono/.test(getComputedStyle(code).fontFamily)) return 'code font ' + getComputedStyle(code).fontFamily;
        if (!/JetBrains Mono/.test(getComputedStyle(pre).fontFamily)) return 'pre font ' + getComputedStyle(pre).fontFamily;
        const surface = getComputedStyle(document.documentElement).getPropertyValue('--code-surface').trim();
        if (!surface) return '--code-surface is not defined';
        const bg = rgba(getComputedStyle(pre).backgroundColor), want = rgba(surface);
        if (bg.slice(0, 3).join() !== want.slice(0, 3).join()) return 'pre background ' + bg + ' is not ' + surface;
        const weak = new Set();
        for (const span of pre.querySelectorAll('span')) {
          const r = ratio(rgba(getComputedStyle(span).color), bg);
          if (r < 4.5) weak.add(getComputedStyle(span).color + ' ' + r.toFixed(2));
        }
        return weak.size ? 'syntax colors below 4.5:1: ' + [...weak].join('; ') : 'ok';
        """)
        |> assert_page("reading links stay distinct from the action color", """
        const link = document.querySelector('#drop-body a');
        if (!link) return 'ok';
        const c = getComputedStyle(link).color;
        return c === 'rgb(89, 71, 241)' ? 'ok' : 'reading link color ' + c;
        """)
        |> shot("drop-#{unquote(name)}-signed-out")
      end

      test "drop page menu stays inside the viewport and covers no trigger (#{name})", %{
        conn: conn,
        drop: drop
      } do
        conn
        |> visit("/d/#{drop.short_id}")
        |> resize(unquote(Macro.escape(size)))
        |> wait_for_element("#action-row-menu-btn-#{drop.id}")
        |> click_selector("#action-row-menu-btn-#{drop.id}")
        |> assert_page("page menu placement", """
        const menu = document.querySelector('#drop-menu-#{drop.id}');
        const btn = document.querySelector('#action-row-menu-btn-#{drop.id}');
        if (!visible(menu)) return 'menu not visible';
        menu.scrollIntoView({ block: 'nearest' });
        const problem = inside(menu, false) || noOverflow();
        if (problem) return problem;
        if (btn.getAttribute('aria-expanded') !== 'true') return 'aria-expanded';
        const b = btn.getBoundingClientRect(), m = menu.getBoundingClientRect();
        if (m.top < b.bottom - 0.5 && m.bottom > b.top + 0.5 && m.left < b.right && m.right > b.left) return 'menu covers its trigger';
        for (const row of menu.querySelectorAll('.menu-row')) if (row.getBoundingClientRect().height < 44) return 'row below the 44px action height';
        for (const h of menu.querySelectorAll('.menu-heading')) if (textContrast(h) < 4.5) return 'heading contrast ' + textContrast(h).toFixed(2);
        for (const row of menu.querySelectorAll('.menu-row')) if (textContrast(row) < 4.5) return 'row contrast ' + textContrast(row).toFixed(2);
        return 'ok';
        """)
        |> shot("drop-menu-#{unquote(name)}-signed-out")
      end

      test "404 page: HTTP 404, h1, recovery links, no overflow (#{name})", %{conn: conn} do
        conn
        |> visit("/this-page-does-not-exist")
        |> resize(unquote(Macro.escape(size)))
        |> assert_page("404 page", """
        const status = (await fetch(location.href)).status;
        if (status !== 404) return 'HTTP ' + status;
        const h1 = document.querySelectorAll('h1');
        if (h1.length !== 1 || !/not found/i.test(h1[0].textContent)) return 'h1: ' + [...h1].map((h) => h.textContent);
        if (!document.querySelector('a[href="/"]')) return 'no home link';
        if (!document.querySelector('a[href="/archive"]')) return 'no archive link';
        if (!/Roboto|sans-serif/.test(getComputedStyle(document.body).fontFamily)) return 'type system not applied';
        const bg = getComputedStyle(document.body).backgroundColor;
        if (bg !== 'rgb(255, 255, 255)') return 'canvas is ' + bg;
        for (const el of document.querySelectorAll('h1, p, a')) if (textContrast(el) < 4.5) return el.tagName + ' contrast ' + textContrast(el).toFixed(2);
        return noOverflow() || 'ok';
        """)
        |> shot("404-#{unquote(name)}")
      end

      test "reduced motion removes card animation and menu transitions (#{name})", %{
        conn: conn,
        drop: drop
      } do
        conn
        |> emulate_reduced_motion()
        |> visit("/d/#{drop.short_id}")
        |> resize(unquote(Macro.escape(size)))
        |> wait_for_element("#drop-menu-#{drop.id}")
        |> assert_page("reduced motion", """
        if (!matchMedia('(prefers-reduced-motion: reduce)').matches) return 'emulation not active';
        const secs = (v) => Math.max(...v.split(',').map((x) => parseFloat(x)));
        const menu = document.querySelector('#drop-menu-#{drop.id}');
        if (secs(getComputedStyle(menu).transitionDuration) > 0.001) return 'menu transition ' + getComputedStyle(menu).transitionDuration;
        if (getComputedStyle(document.documentElement).scrollBehavior !== 'auto') return 'smooth scrolling';
        return 'ok';
        """)
        |> visit("/")
        |> wait_for_element(".drop-card")
        |> assert_page("reduced motion card", """
        const secs = (v) => Math.max(...v.split(',').map((x) => parseFloat(x)));
        const card = document.querySelector('.drop-card');
        if (secs(getComputedStyle(card).animationDuration) > 0.001) return 'card animation ' + getComputedStyle(card).animationDuration;
        if (secs(getComputedStyle(card).transitionDuration) > 0.001) return 'card transition ' + getComputedStyle(card).transitionDuration;
        return 'ok';
        """)
      end
    end

    describe "#{name} viewport, signed in" do
      @describetag error_path_exemption:
                     "Authorization refusals are unchanged and covered by visitor_authentication_test."
      setup do
        content = create_content()
        search_history_fixture(%{user_id: content.author.id, query: "Visual check"})
        content
      end

      test "card menu: placement, roles and hover contrast (#{name})", %{
        conn: conn,
        author: author,
        drop: drop
      } do
        menu_button = "#drop-card-menu-btn-#{drop.id}"

        conn
        |> sign_in_user(author)
        |> visit("/profile")
        |> resize(unquote(Macro.escape(size)))
        |> wait_for_element(menu_button)
        |> assert_page("card title is an h2", """
        return document.querySelector('.drop-card h2.drop-title') ? (noOverflow() || 'ok') : 'no h2.drop-title';
        """)
        |> click_selector(menu_button)
        |> assert_page("card menu placement", """
        const menu = document.querySelector('#drop-card-menu-#{drop.id}');
        const btn = document.querySelector('#{menu_button}');
        if (!visible(menu)) return 'menu not visible';
        menu.scrollIntoView({ block: 'nearest' });
        const problem = inside(menu, #{elem(unquote(Macro.escape(size)), 1) >= 800}) || noOverflow();
        if (problem) return problem;
        const b = btn.getBoundingClientRect(), m = menu.getBoundingClientRect();
        if (m.top < b.bottom - 0.5 && m.bottom > b.top + 0.5 && m.left < b.right && m.right > b.left) return 'menu covers its trigger';
        const rows = menu.querySelectorAll('.menu-row');
        if (rows.length < 3) return 'expected share, markdown and edit rows, got ' + rows.length;
        for (const row of rows) if (row.getBoundingClientRect().height < 44) return 'row below the 44px action height';
        if (!menu.querySelector('.menu-heading') || !menu.querySelector('.menu-separator')) return 'heading or separator role missing';
        for (const h of menu.querySelectorAll('.menu-heading')) if (textContrast(h) < 4.5) return 'heading contrast ' + textContrast(h).toFixed(2);
        for (const row of rows) if (textContrast(row) < 4.5) return 'row contrast ' + textContrast(row).toFixed(2);
        return 'ok';
        """)
        |> shot("card-menu-#{unquote(name)}")
        |> hover_selector("#card-copy-link-menu-#{drop.id}")
        |> assert_page("menu row hover contrast", """
        const row = document.querySelector('#drop-card-menu-#{drop.id} .menu-row');
        const r = textContrast(row);
        return r >= 4.5 ? 'ok' : 'hover contrast ' + r.toFixed(2) + ' (' + getComputedStyle(row).color + ' on ' + getComputedStyle(row).backgroundColor + ')';
        """)
        |> press_key("Shift")
        |> assert_page("menu row focus outline", """
        const row = document.querySelector('#drop-card-menu-#{drop.id} .menu-row');
        row.focus();
        const s = getComputedStyle(row);
        if (!row.matches(':focus-visible')) return 'row not :focus-visible after keyboard input';
        if (s.outlineStyle === 'none') return 'focused menu row has no outline';
        const outline = ratio(rgba(s.outlineColor), [255, 255, 255, 1]);
        return outline >= 3 ? 'ok' : 'focus outline contrast ' + outline.toFixed(2);
        """)
      end

      test "account menu: placement and roles (#{name})", %{conn: conn, author: author} do
        conn
        |> sign_in_user(author)
        |> visit("/")
        |> resize(unquote(Macro.escape(size)))
        |> wait_for_element("#account-menu-trigger")
        |> click_selector("#account-menu-trigger")
        |> assert_page("account menu", """
        const menu = document.querySelector('#slide-menu');
        if (!visible(menu)) return 'menu not visible';
        const problem = inside(menu, false) || noOverflow();
        if (problem) return problem;
        const rows = menu.querySelectorAll('.menu-row');
        if (rows.length !== 2) return 'rows ' + rows.length;
        for (const row of rows) if (row.getBoundingClientRect().height < 44) return 'row below the 44px action height';
        if (!menu.querySelector('.menu-separator')) return 'separator role missing';
        return 'ok';
        """)
        |> shot("account-menu-#{unquote(name)}")
      end

      test "notification panel: placement and no overflow (#{name})", %{
        conn: conn,
        author: author
      } do
        trigger =
          if elem(unquote(Macro.escape(size)), 0) < 640,
            do: "#notifications-trigger-mobile",
            else: "#notifications-trigger"

        conn
        |> sign_in_user(author)
        |> visit("/")
        |> resize(unquote(Macro.escape(size)))
        |> wait_for_element(trigger)
        |> click_selector(trigger)
        |> assert_page("notification panel", """
        const panel = document.querySelector('#notifications-container');
        if (!visible(panel)) return 'panel not visible';
        const problem = inside(panel, false) || noOverflow();
        if (problem) return problem;
        return 'ok';
        """)
        |> shot("notifications-#{unquote(name)}")
      end

      test "search suggestions: inside the viewport, readable, no overflow (#{name})", %{
        conn: conn,
        author: author
      } do
        conn
        |> sign_in_user(author)
        |> visit("/")
        |> resize(unquote(Macro.escape(size)))
        |> wait_for_element(".drop-card")
        |> then(fn session ->
          if elem(unquote(Macro.escape(size)), 0) < 1024 do
            click_selector(session, "#search-trigger")
          else
            session
          end
        end)
        |> type_in_search("Visual")
        |> assert_page("search suggestions", """
        const list = [...document.querySelectorAll('[role="listbox"]')].find(visible);
        if (!list) return 'no suggestions listbox';
        const box = list.parentElement;
        const problem = inside(box, false) || noOverflow();
        if (problem) return problem;
        for (const opt of list.querySelectorAll('[role="option"]')) if (textContrast(opt) < 4.5) return 'option contrast ' + textContrast(opt).toFixed(2);
        const input = document.activeElement;
        if (input && input.tagName === 'INPUT') {
          const border = ratio(rgba(getComputedStyle(input).borderTopColor), [255, 255, 255, 1]);
          if (border < 3) return 'search input boundary contrast ' + border.toFixed(2);
        }
        return 'ok';
        """)
        |> shot("search-suggestions-#{unquote(name)}")
      end
    end
  end
end
