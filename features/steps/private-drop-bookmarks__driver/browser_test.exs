Code.require_file("support.exs", __DIR__)

defmodule PrivateDropBookmarks.BrowserTest do
  use ElixirDropsWeb.FeatureCase, async: false

  alias ElixirDrops.Drops.Drop
  alias PhoenixTest.Playwright.Frame

  @moduletag :feature
  @moduletag timeout: 100_000

  @lib """
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const until = async (fn, ms = 8500) => { const end = Date.now() + ms; let v = fn(); while (!v && Date.now() < end) { await sleep(50); v = fn(); } return v; };
  const cardOf = (title) => [...document.querySelectorAll('.drop-card')].find((c) => c.querySelector('h2') && c.querySelector('h2').textContent.trim() === title);
  const bm = (root) => [...root.querySelectorAll('button')].find((b) => /bookmark/i.test(b.textContent + ' ' + (b.getAttribute('aria-label') || '')) && b.hasAttribute('aria-pressed'));
  const isSaved = (b) => !!b && b.getAttribute('aria-pressed') === 'true';
  const cardButton = (title) => { const c = cardOf(title); return c && bm(c); };
  const visible = (el) => !!el && el.checkVisibility() && el.getBoundingClientRect().height > 0;
  const prompted = () => { const d = document.querySelector('#signin-popup-message'); return visible(d) && /sign in with github/i.test(d.textContent); };
  const countPhrase = () => /\\b\\d+\\s+bookmarks?\\b/i.test(document.body.innerText);
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
          value = try do Frame.evaluate(frame_id, "(() => { #{@lib} return #{expr}; })()", timeout: 2_000) rescue _ -> false end
          if value == true, do: true, else: (Process.sleep(200); false)
        end)

      assert ok?, "#{label}: condition never became true: #{expr}"
    end)
  end

  @title "BRW Journey drop"

  test "signed-out visitors are prompted to sign in and a signed-in visitor completes the bookmark journey", %{conn: conn} do
    me = user_fixture(%{github_username: "browserbookmarker"})
    author = user_fixture(%{github_username: "browserauthor"})
    drop = drop_fixture(%Drop{}, author, %{title: @title})

    # Signed out, homepage: the action is offered in the card menu and asks for sign-in.
    session = visit(conn, "/")
    await_js(session, "card", "!!cardOf('#{@title}')")
    js(session, "guest homepage", """
    const card = cardOf('#{@title}');
    card.querySelector('[id^="drop-card-menu-btn-"]').click();
    if (!(await until(() => visible(cardButton('#{@title}'))))) return 'Bookmark control not visible in the card menu';
    if (isSaved(cardButton('#{@title}'))) return 'guest control must not be saved';
    cardButton('#{@title}').click();
    if (!(await until(prompted))) return 'no sign-in prompt after selecting Bookmark on the homepage';
    return 'ok';
    """)

    # Signed out, Drop page: a visible button beside Copy link, same prompt, no count.
    session = visit(session, "/d/#{drop.short_id}")
    await_js(session, "drop page", "!!bm(document)")
    js(session, "guest drop page", """
    const b = bm(document);
    const copy = document.querySelector('[id^="single-drop-copy-link-"]');
    if (!visible(b)) return 'Bookmark button is not visible without opening a menu';
    if (b.parentElement !== copy.parentElement) return 'Bookmark button is not beside Copy link';
    if (countPhrase()) return 'a count is shown at zero';
    b.click();
    if (!(await until(prompted))) return 'no sign-in prompt on the Drop page';
    return 'ok';
    """)

    # Signed in: the guest attempts saved nothing; save from the homepage menu.
    session = session |> sign_in_user(me) |> visit("/")
    await_js(session, "card", "!!cardButton('#{@title}')")
    js(session, "save", """
    if (isSaved(cardButton('#{@title}'))) return 'nothing may have been saved while signed out';
    cardOf('#{@title}').querySelector('[id^="drop-card-menu-btn-"]').click();
    if (!(await until(() => visible(cardButton('#{@title}'))))) return 'control not visible';
    cardButton('#{@title}').click();
    if (!(await until(() => isSaved(cardButton('#{@title}'))))) return 'card did not show saved';
    cardOf('#{@title}').querySelector('h2 a').click();
    return 'ok';
    """)

    # The Drop page shows it saved with a count of 1.
    await_js(session, "drop page", "location.pathname === '/d/#{drop.short_id}' && isSaved(bm(document))")
    await_js(session, "count", "/\\b1\\s+bookmark\\b/i.test(document.body.innerText)")

    # Account menu -> Bookmarks lists it; remove it there; the empty state appears.
    js(session, "open bookmarks", """
    document.querySelector('#account-menu-trigger').click();
    const link = [...document.querySelectorAll('#slide-menu a')].find((a) => a.textContent.trim() === 'Bookmarks');
    if (!link || !(await until(() => visible(link)))) return 'no visible Bookmarks link in the account menu';
    link.click();
    return 'ok';
    """)
    await_js(session, "listed", "!!cardOf('#{@title}')")
    js(session, "remove", """
    cardOf('#{@title}').querySelector('[id^="drop-card-menu-btn-"]').click();
    if (!(await until(() => visible(cardButton('#{@title}'))))) return 'control not visible in Bookmarks';
    if (!isSaved(cardButton('#{@title}'))) return 'Bookmarks card is not saved';
    cardButton('#{@title}').click();
    if (!(await until(() => !cardOf('#{@title}')))) return 'removed Drop is still listed';
    if (!(await until(() => /no bookmarks yet/i.test(document.body.innerText)))) return 'no empty state';
    return 'ok';
    """)

    # The Drop page agrees: unsaved, and the count is gone.
    session = visit(session, "/d/#{drop.short_id}")
    await_js(session, "unsaved", "!!bm(document) && !isSaved(bm(document)) && !countPhrase()")
  end
end
