defmodule LinkPublicContributorAttributions.BrowserTest do
  use ElixirDropsWeb.FeatureCase, async: true

  alias ElixirDrops.Drops.Drop
  alias PhoenixTest.Playwright.Frame

  @moduletag :feature

  defp js(session, label, script) do
    unwrap(session, fn %{frame_id: frame_id} ->
      wrapped = "(async () => { #{script} })()"
      result = Frame.evaluate(frame_id, wrapped, timeout: 10_000)
      assert result == "ok", "#{label}: #{inspect(result)}"
    end)
  end

  # Waits (bounded polling, no fixed sleep) until the page script resolves to "ok".
  defp poll(session, label, script) do
    js(session, label, """
    const check = () => { #{script} };
    let r = check();
    for (let i = 0; i < 100 && r !== 'ok'; i++) { await new Promise((res) => setTimeout(res, 50)); r = check(); }
    return r;
    """)
  end

  defp cards_js(title_a, title_b) do
    """
    const cardOf = (title) => [...document.querySelectorAll('.drop-card')].find((c) => c.querySelector('h2') && c.querySelector('h2').textContent.trim() === title);
    const cards = { a: cardOf('#{title_a}'), b: cardOf('#{title_b}') };
    """
  end

  defp click_opts(_frame_id, :middle), do: %{button: "middle"}

  # The platform's open-in-new-tab modifier: Command on macOS (where Chromium turns
  # Control+left-click into a context-menu gesture that never dispatches `click`),
  # Control elsewhere.
  defp click_opts(frame_id, :modifier) do
    mac? = Frame.evaluate(frame_id, "/Mac|iPhone|iPad/.test(navigator.platform)")
    %{modifiers: [if(mac? == true, do: "Meta", else: "Control")]}
  end

  test "author links behave as native independent anchors at 320, 390 and 1280 px", %{conn: conn} do
    alpha = user_fixture(%{name: "Alpha Author", github_username: "alpha_author"})
    beta = user_fixture(%{name: "Beta Author", github_username: "beta_author"})
    drop_fixture(%Drop{}, alpha, %{title: "Browser fixture Alpha"})
    drop_fixture(%Drop{}, beta, %{title: "Browser fixture Beta"})

    session =
      conn
      |> visit("/")
      |> wait_for_element(".drop-card")
      |> resize_window(1280, 800)

    cards = cards_js("Browser fixture Alpha", "Browser fixture Beta")
    profile = "/u/#{alpha.id}"

    # One anchor at a time: the first author link of card A (avatar and name may be one anchor or two).
    first_author = ":nth-match(.drop-card a[href=\"#{profile}\"], 1)"

    # Structure: both cards' author links point at their own author; no anchor has an anchor ancestor.
    poll(session, "structure", """
    #{cards}
    if (!cards.a || !cards.b) return 'fixture cards not rendered';
    const links = (c) => [...c.querySelectorAll('a')].filter((a) => new URL(a.href).pathname.startsWith('/u/'));
    const la = links(cards.a), lb = links(cards.b);
    if (!la.length || !lb.length) return 'author links missing';
    if (!la.every((a) => new URL(a.href).pathname === '/u/#{alpha.id}')) return 'card A links elsewhere';
    if (!lb.every((a) => new URL(a.href).pathname === '/u/#{beta.id}')) return 'card B links elsewhere';
    const nested = [...document.querySelectorAll('a')].filter((a) => a.parentElement && a.parentElement.closest('a'));
    if (nested.length) return 'nested anchors: ' + nested.length;
    return 'ok';
    """)

    # Keyboard: Tab until an author link of card A is focused, then Enter opens its profile in this tab.
    unwrap(session, fn %{frame_id: frame_id} ->
      focused? = fn ->
        Frame.evaluate(frame_id, """
        (() => { const el = document.activeElement; return !!el && el.tagName === 'A' && new URL(el.href).pathname === '/u/#{alpha.id}' && !!el.closest('.drop-card'); })()
        """)
      end

      Enum.reduce_while(1..80, nil, fn _, _ ->
        if focused?.() == true do
          {:halt, :focused}
        else
          Frame.press(frame_id, "body", "Tab")
          {:cont, nil}
        end
      end)

      assert focused?.() == true, "no author link received focus through Tab"
      Frame.press(frame_id, "*:focus", "Enter")
    end)

    poll(session, "enter opens profile in the same tab", "return location.pathname === '#{profile}' ? 'ok' : location.pathname;")

    js(session, "history back", "history.back(); return 'ok';")
    wait_for_element(session, ".drop-card")
    poll(session, "back to list", "return location.pathname === '/' && document.querySelector('.drop-card') ? 'ok' : location.pathname;")

    # Modifier-click (Command on macOS, Control elsewhere) and middle-click: stay on this URL,
    # never default-prevented, never reach the Drop or the options menu. The mouse event the
    # platform really dispatches is observed: `click` for the modifier-click, `click` or `auxclick`
    # for the middle-click.
    for {label, kind} <- [{"modifier-click", :modifier}, {"middle-click", :middle}] do
      js(session, "#{label} listener", """
      window.__seen = [];
      for (const type of ['click', 'auxclick']) window.addEventListener(type, (e) => { window.__seen.push({ type, prevented: e.defaultPrevented }); });
      return 'ok';
      """)

      unwrap(session, fn %{frame_id: frame_id} ->
        opts = click_opts(frame_id, kind)
        {:ok, _} = Frame.click(frame_id, first_author, Map.merge(%{timeout: 5_000}, opts))
      end)

      poll(session, "#{label} stays on the list", """
      if (location.pathname !== '/') return 'navigated to ' + location.pathname;
      if (!window.__seen.length) return 'click not observed';
      if (window.__seen.some((s) => s.prevented)) return 'click was default-prevented';
      if (document.querySelector('.drop-card [aria-expanded="true"]')) return 'options menu opened';
      return 'ok';
      """)
    end

    # Visible focus indicator and pointer cursor at the three widths, measured without reloading.
    for width <- [320, 390, 1280] do
      resize_window(session, width, 800)

      unwrap(session, fn %{frame_id: frame_id} ->
        Frame.evaluate(frame_id, "document.activeElement && document.activeElement.blur()")

        Enum.reduce_while(1..80, nil, fn _, _ ->
          focused =
            Frame.evaluate(frame_id, """
            (() => { const el = document.activeElement; return !!el && el.tagName === 'A' && new URL(el.href).pathname === '/u/#{alpha.id}' && !!el.closest('.drop-card'); })()
            """)

          if focused == true do
            {:halt, :focused}
          else
            Frame.press(frame_id, "body", "Tab")
            {:cont, nil}
          end
        end)
      end)

      poll(session, "focus and cursor at #{width}px", """
      const el = document.activeElement;
      if (!el || el.tagName !== 'A' || new URL(el.href).pathname !== '/u/#{alpha.id}') return 'author link not focused';
      const cs = getComputedStyle(el);
      const outline = cs.outlineStyle !== 'none' && parseFloat(cs.outlineWidth) > 0;
      const shadow = cs.boxShadow && cs.boxShadow !== 'none';
      if (!outline && !shadow) return 'no visible focus indicator';
      if (cs.cursor !== 'pointer') return 'cursor is ' + cs.cursor;
      const r = el.getBoundingClientRect();
      if (r.width === 0 || r.height === 0) return 'link not visible';
      if (window.innerWidth !== #{width}) return 'viewport is ' + window.innerWidth;
      return 'ok';
      """)
    end

    # A plain click on one author link opens the profile, not the Drop.
    resize_window(session, 1280, 800)

    unwrap(session, fn %{frame_id: frame_id} ->
      {:ok, _} = Frame.click(frame_id, first_author, %{timeout: 5_000})
    end)

    poll(session, "plain click opens the author's profile", "return location.pathname === '#{profile}' ? 'ok' : location.pathname;")
  end
end
