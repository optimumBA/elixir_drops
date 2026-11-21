Code.require_file("support.exs", __DIR__)

defmodule PublicProfileCommentsTabCorrected.DiscussionBrowserTest do
  use ElixirDropsWeb.FeatureCase, async: false

  import ElixirDrops.CommentsFixtures

  alias ElixirDrops.Drops.Drop
  alias PhoenixTest.Playwright.Frame
  alias PublicProfileCommentsTabCorrected.Support, as: S

  @moduletag :feature
  @moduletag timeout: 100_000

  @lib """
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const until = async (fn, ms = 8500) => { const end = Date.now() + ms; let v = fn(); while (!v && Date.now() < end) { await sleep(50); v = fn(); } return v; };
  const textNode = (root, needle) => { const w = document.createTreeWalker(root, NodeFilter.SHOW_TEXT); let n; while ((n = w.nextNode())) { if (n.textContent.includes(needle)) return n; } return null; };
  const rectOf = (n) => { const g = document.createRange(); g.selectNodeContents(n); return g.getBoundingClientRect(); };
  const entryOf = (token) => { const n = textNode(document.querySelector('#profile-comments'), token); let el = n && n.parentElement; while (el && el.id !== 'profile-comments') { if ([...el.querySelectorAll('a')].some((a) => /View in discussion/i.test(a.textContent))) return el; el = el.parentElement; } return null; };
  const revealed = (el, tail) => { const n = textNode(el, tail); if (!n) return false; const r = rectOf(n); const e = el.getBoundingClientRect(); return r.height > 0 && r.top >= e.top - 1 && r.bottom <= e.bottom + 1; };
  const inView = (token) => { const n = textNode(document.body, token); if (!n || !n.parentElement.checkVisibility()) return false; const r = rectOf(n); return r.height > 0 && r.top >= 0 && r.bottom <= innerHeight; };
  """

  defp js(session, label, script) do
    unwrap(session, fn %{frame_id: frame_id} ->
      result = Frame.evaluate(frame_id, "(async () => { #{@lib} #{script} })()", timeout: 10_000)
      assert result == "ok", "#{label}: #{inspect(result)}"
    end)
  end

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

  defp open_discussion(session, token) do
    js(session, "open #{token}", """
    if (!(await until(() => entryOf('#{token}')))) return 'no entry for #{token}';
    const link = [...entryOf('#{token}').querySelectorAll('a')].find((a) => /View in discussion/i.test(a.textContent));
    link.click();
    return 'ok';
    """)

    await_js(session, "drop page for #{token}", "location.pathname.startsWith('/d/')")
    js(session, "reveal #{token}", """
    if (!(await until(() => inView('#{token}')))) return '#{token} is not revealed inside the viewport on the Drop page; scrollY=' + scrollY;
    return 'ok';
    """)
  end

  test "expand works from the keyboard and View in discussion reveals the exact older reply and comment", %{conn: conn} do
    author = user_fixture(%{name: "Disc Author"})
    rival = user_fixture(%{name: "Disc Rival"})
    deep = drop_fixture(%Drop{}, rival, %{title: "Deep Drop"})
    other = drop_fixture(%Drop{}, rival, %{title: "Long Drop"})

    # Newer conversation: 25 top-level comments, more than the Drop page loads initially.
    for i <- 1..25 do
      c = comment_fixture(deep, rival, nil, %{body: "OTH-#{S.pad(i)} newer conversation"})
      S.set_inserted_at(c, NaiveDateTime.add(~N[2025-06-01 12:00:00], i * 60))
    end

    old_parent = comment_fixture(deep, rival, nil, %{body: "PAR-0001 oldest conversation"})
    S.set_inserted_at(old_parent, ~N[2023-01-01 12:00:00])
    reply = comment_fixture(deep, author, old_parent, %{body: "RPL-0001 old reply"})
    S.set_inserted_at(reply, ~N[2024-05-01 12:00:00])
    old = comment_fixture(deep, author, nil, %{body: "CMT-0002 old top-level comment"})
    S.set_inserted_at(old, ~N[2023-06-01 12:00:00])
    long = comment_fixture(other, author, nil, %{body: "CMT-0003 " <> String.duplicate("word ", 196) <> "LONGTAIL"})
    S.set_inserted_at(long, ~N[2024-03-05 12:00:00])
    path = S.comments_path(author)

    session = conn |> visit(path) |> resize_window(1280, 800)

    js(session, "entries", """
    if (!(await until(() => entryOf('CMT-0003') && entryOf('RPL-0001') && entryOf('CMT-0002')))) return 'entries missing';
    if (/not available yet/i.test(document.querySelector('#profile-comments').textContent)) return 'placeholder shown';
    return 'ok';
    """)

    # Keyboard expand/collapse on the long entry, with visible focus on the control.
    unwrap(session, fn %{frame_id: frame_id} ->
      focused? = fn ->
        Frame.evaluate(frame_id, """
        (() => { const a = document.activeElement; return !!a && a.matches('button[aria-expanded]') && !!a.closest('#profile-comments') && a.closest('#profile-comments').textContent.includes('CMT-0003') && (a.parentElement.closest('div') || a).textContent.includes('CMT-0003'); })()
        """) == true
      end

      Enum.find(1..120, fn _ -> Frame.press(frame_id, "body", "Tab"); focused?.() end)
      assert focused?.(), "Tab never reached an expand control"

      state = fn -> Frame.evaluate(frame_id, "document.activeElement.getAttribute('aria-expanded')") end
      ring = Frame.evaluate(frame_id, "(() => { const s = getComputedStyle(document.activeElement); return s.outlineStyle !== 'none' || s.boxShadow !== 'none'; })()")
      assert ring == true, "no visible focus indication on the expand control"
      assert state.() == "false"
      assert Frame.evaluate(frame_id, "(() => { const e = document.activeElement.closest('#profile-comments'); return e.textContent.includes('LONGTAIL'); })()") == true
      Frame.press(frame_id, "*:focus", "Enter")
      assert state.() == "true"
    end)

    js(session, "expanded", """
    const el = entryOf('CMT-0003');
    if (!(await until(() => revealed(el, 'LONGTAIL')))) return 'tail not revealed after expanding';
    return 'ok';
    """)

    unwrap(session, fn %{frame_id: frame_id} ->
      Frame.press(frame_id, "*:focus", "Enter")
      assert Frame.evaluate(frame_id, "document.activeElement.getAttribute('aria-expanded')") == "false"
    end)

    js(session, "collapsed", """
    const el = entryOf('CMT-0003');
    if (!(await until(() => !revealed(el, 'LONGTAIL')))) return 'tail still revealed after collapsing';
    return 'ok';
    """)

    # View in discussion: the exact older reply (inside a conversation beyond the first loaded ones).
    open_discussion(session, "RPL-0001")

    # And the exact older top-level comment.
    session = visit(session, path)
    open_discussion(session, "CMT-0002")
  end
end
