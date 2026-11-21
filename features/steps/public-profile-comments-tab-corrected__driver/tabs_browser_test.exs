Code.require_file("support.exs", __DIR__)

defmodule PublicProfileCommentsTabCorrected.TabsBrowserTest do
  use ElixirDropsWeb.FeatureCase, async: false

  alias PhoenixTest.Playwright.Frame
  alias PublicProfileCommentsTabCorrected.Support, as: S

  @moduletag :feature
  @moduletag timeout: 100_000

  @lib """
  const TOKRE = /\\b(?:CMT|RPL)-\\d{4}\\b/g;
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const rectOf = (n) => { const g = document.createRange(); g.selectNodeContents(n); return g.getBoundingClientRect(); };
  const found = () => { const r = document.querySelector('#profile-comments'); const out = []; if (!r) return out; const w = document.createTreeWalker(r, NodeFilter.SHOW_TEXT); let n; while ((n = w.nextNode())) { for (const t of (n.textContent.match(TOKRE) || [])) out.push({ token: t, node: n }); } return out; };
  const tokens = () => found().map((e) => e.token);
  const firstVisible = () => { for (const e of found()) { const r = rectOf(e.node); if (r.height > 0 && r.bottom > 0 && r.top < innerHeight) return e.token; } return null; };
  const cards = () => [...document.querySelectorAll('#profile-drops-feed .drop-card')];
  const cardTitle = (c) => (c.querySelector('h2') ? c.querySelector('h2').textContent.trim() : c.textContent.trim().slice(0, 40));
  const firstCard = () => { for (const c of cards()) { const r = c.getBoundingClientRect(); if (r.height > 0 && r.bottom > 0 && r.top < innerHeight) return cardTitle(c); } return null; };
  const until = async (fn, ms = 8500) => { const end = Date.now() + ms; let v = fn(); while (!v && Date.now() < end) { await sleep(50); v = fn(); } return v; };
  const bottom = () => window.scrollTo(0, document.documentElement.scrollHeight);
  const isPrefix = (a, b) => a.length <= b.length && a.every((x, i) => x === b[i]);
  const unique = (a) => new Set(a).size === a.length;
  const noPlaceholder = () => !/not available yet/i.test((document.querySelector('#profile-comments') || document.body).textContent);
  """

  defp js(session, label, script) do
    unwrap(session, fn %{frame_id: frame_id} ->
      result = Frame.evaluate(frame_id, "(async () => { #{@lib} #{script} })()", timeout: 10_000)
      assert result == "ok", "#{label}: #{inspect(result)}"
    end)
  end

  # Bounded polling from Elixir across a page navigation (the JS context is replaced).
  defp await_js(session, label, expr) do
    unwrap(session, fn %{frame_id: frame_id} ->
      ok? =
        Enum.find_value(1..40, false, fn _ ->
          value = try do Frame.evaluate(frame_id, expr, timeout: 2_000) rescue _ -> false end
          if value == true, do: true, else: (Process.sleep(200); false)
        end)

      assert ok?, "#{label}: condition never became true: #{expr}"
    end)
  end

  test "both tabs keep entries and position across switching, an interrupted batch and Back", %{conn: conn} do
    author = user_fixture(%{name: "Tab Author"})
    rival = user_fixture(%{name: "Tab Rival"})
    create_multiple_drops(author, 33)
    %{entries: entries} = S.build_activity(author, rival, 44)
    all = Enum.map(entries, & &1.token)
    base = "/u/#{author.id}"

    session = conn |> visit(base <> "/drops") |> resize_window(1280, 800)

    # Drops tab: load two batches and park on a later card.
    js(session, "drops", """
    if (!(await until(() => cards().length >= 10))) return 'no drops';
    for (let i = 0; i < 50 && cards().length < 30; i++) { bottom(); await sleep(150); }
    if (cards().length < 30) return 'drops did not load more: ' + cards().length;
    cards()[18].scrollIntoView({ block: 'start' }); await sleep(300);
    sessionStorage.setItem('pct-drops', JSON.stringify({ titles: cards().map(cardTitle), first: firstCard() }));
    return 'ok';
    """)

    # Comments tab by keyboard: Tab to the tab link, Enter, focus stays on it and is visible.
    unwrap(session, fn %{frame_id: frame_id} ->
      Frame.evaluate(frame_id, "window.scrollTo(0, 0)")

      focused? = fn -> Frame.evaluate(frame_id, "document.activeElement && document.activeElement.id === 'profile-comments-tab'") == true end

      Enum.find(1..80, fn _ -> Frame.press(frame_id, "body", "Tab"); focused?.() end)
      assert focused?.(), "Tab never reached the Comments tab link"
      Frame.press(frame_id, "*:focus", "Enter")
    end)

    js(session, "first batch", """
    if (!(await until(() => tokens().length >= 10))) return 'no entries: ' + tokens().length;
    if (!noPlaceholder()) return 'placeholder shown';
    if (tokens().length !== 10) return 'first batch size ' + tokens().length;
    const a = document.activeElement;
    if (!a || a.id !== 'profile-comments-tab') return 'focus lost from the tab link';
    if (!a.matches(':focus-visible')) return 'focus not visible';
    const tops = found().map((e) => rectOf(e.node).top);
    for (let i = 1; i < tops.length; i++) if (!(tops[i] > tops[i - 1] + 1)) return 'not a single column at entry ' + i;
    for (let i = 0; i < 60 && tokens().length < 20; i++) { bottom(); await sleep(150); }
    if (tokens().length < 20) return 'second batch missing: ' + tokens().length;
    await sleep(600);
    const n = tokens().length;
    if (n >= 40) return 'overshoot ' + n;
    found()[12].node.parentElement.scrollIntoView({ block: 'start' }); await sleep(300);
    sessionStorage.setItem('pct-comments', JSON.stringify({ loaded: tokens(), first: firstVisible() }));
    return 'ok';
    """)

    # Interrupted batch: hold the next comments batch, switch to Drops, release, switch back.
    S.hold(self(), "pct-tab-hold", "comments")
    js(session, "trigger", "for (let i = 0; i < 10; i++) { bottom(); await sleep(100); } return 'ok';")
    assert_receive {:held, task}, 10_000

    js(session, "to drops", """
    document.querySelector('#profile-drops-tab').click();
    if (!(await until(() => cards().length > 0 && cards()[0].getBoundingClientRect().height > 0))) return 'drops not shown';
    return 'ok';
    """)

    send(task, :release)
    :telemetry.detach("pct-tab-hold")

    js(session, "drops kept", """
    const saved = JSON.parse(sessionStorage.getItem('pct-drops'));
    if (!(await until(() => isPrefix(saved.titles, cards().map(cardTitle))))) return 'drop entries lost on switch';
    if (!(await until(() => firstCard() === saved.first))) return 'drops position lost: ' + firstCard() + ' vs ' + saved.first;
    document.querySelector('#profile-comments-tab').click();
    const c = JSON.parse(sessionStorage.getItem('pct-comments'));
    if (!(await until(() => isPrefix(c.loaded, tokens())))) return 'comment entries lost or reordered: ' + tokens().length;
    if (!unique(tokens())) return 'duplicates after interrupted batch';
    if (tokens().length > c.loaded.length + 10) return 'more than one batch appended';
    if (!(await until(() => firstVisible() === c.first))) return 'comments position lost: ' + firstVisible() + ' vs ' + c.first;
    return 'ok';
    """)

    # Back from a Drop: follow the first visible entry's Drop title, then history.back().
    js(session, "open drop", """
    const first = found().find((e) => e.token === firstVisible());
    sessionStorage.setItem('pct-back', JSON.stringify({ loaded: tokens(), first: firstVisible() }));
    let el = first.node.parentElement; let link = null;
    while (el && el.id !== 'profile-comments' && !link) { link = [...el.querySelectorAll('a')].find((a) => new URL(a.href).pathname.startsWith('/d/') && !/discussion/i.test(a.textContent)); if (!link) el = el.parentElement; }
    if (!link) return 'no Drop title link in the entry';
    link.click();
    return 'ok';
    """)

    await_js(session, "on drop page", "location.pathname.startsWith('/d/')")
    unwrap(session, fn %{frame_id: frame_id} -> Frame.evaluate(frame_id, "history.back()") end)
    await_js(session, "back on profile", "location.pathname === '#{base}/comments' && document.querySelectorAll('#profile-comments').length === 1")

    js(session, "restored", """
    const b = JSON.parse(sessionStorage.getItem('pct-back'));
    if (!(await until(() => isPrefix(b.loaded, tokens())))) return 'entries not restored after Back: ' + tokens().length + ' of ' + b.loaded.length;
    if (!(await until(() => firstVisible() === b.first))) return 'position not restored after Back: ' + firstVisible() + ' vs ' + b.first;
    for (let i = 0; i < 120 && tokens().length < #{length(all)}; i++) { bottom(); await sleep(100); }
    const t = tokens();
    if (t.length !== #{length(all)} || !unique(t)) return 'final list wrong: ' + t.length;
    if ([...t].sort().join() !== #{Jason.encode!(Enum.sort(all))}.join()) return 'entry set differs';
    return 'ok';
    """)

    # Phone viewport: the tab shows entries, never the placeholder.
    session = session |> resize_window(390, 844) |> visit(base <> "/comments")

    js(session, "phone", """
    if (!(await until(() => tokens().length >= 10))) return 'no entries on phone: ' + tokens().length;
    if (!noPlaceholder()) return 'placeholder on phone';
    const tops = found().map((e) => rectOf(e.node).top);
    for (let i = 1; i < tops.length; i++) if (!(tops[i] > tops[i - 1] + 1)) return 'not a single column on phone at ' + i;
    return 'ok';
    """)
  end
end
