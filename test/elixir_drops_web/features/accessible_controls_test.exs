defmodule ElixirDropsWeb.Features.AccessibleControlsTest do
  @moduledoc """
  Browser regression tests for native navigation and accessible controls.

  Drives the shared interactive controls through real clicks, modifier-clicks,
  middle-clicks, keyboard input and focus at desktop (1280px) and phone (390px)
  widths: Drop cards, copy actions, header triggers, search suggestions,
  dialogs, clipboard feedback and image alternatives.

  Run with `FEATURE_TESTS=true mix test --include feature`.
  """

  use ElixirDropsWeb.FeatureCase, async: true

  import ElixirDrops.FeatureHelpers

  alias ElixirDrops.Drops.Drop
  alias PhoenixTest.Playwright.Frame

  @moduletag :feature

  @body """
  def example(data) do
    case data do
      {:ok, value} -> value
      _ -> :error
    end
  end
  """

  # Runs a JavaScript expression in the page, polling until it resolves to "ok"
  # (up to 3 seconds); any other final value is the failure description.
  defp assert_page(session, label, js) do
    assert_page_after(session, label, 0, js)
  end

  # Waits `delay` milliseconds in the page, then polls like assert_page/3. Used
  # for outcomes that must hold after the browser had time to act, such as "the
  # tab did not navigate".
  defp assert_page_after(session, label, delay, js) do
    unwrap(session, fn %{frame_id: frame_id} ->
      script = """
      (async () => {
        await new Promise((resolve) => setTimeout(resolve, #{delay}));
        const check = async () => { #{js} };
        let result = await check();
        for (let i = 0; i < 60 && result !== 'ok'; i++) {
          await new Promise((resolve) => setTimeout(resolve, 50));
          result = await check();
        }
        return result;
      })()
      """

      result = Frame.evaluate(frame_id, script, timeout: 10_000)
      assert result == "ok", "#{label}: #{inspect(result)}"
    end)
  end

  defp assert_on_root(session, label) do
    assert_page_after(
      session,
      label,
      300,
      "return location.pathname === '/' ? 'ok' : location.pathname;"
    )
  end

  defp click_with(session, selector, opts) do
    unwrap(session, fn %{frame_id: frame_id} ->
      {:ok, _result} = Frame.click(frame_id, selector, Enum.into(opts, %{timeout: 5_000}))
    end)
  end

  defp press_focused(session, key) do
    unwrap(session, fn %{frame_id: frame_id} ->
      {:ok, _result} = Frame.press(frame_id, "*:focus", key)
    end)
  end

  # Every button, link and image has an accessible name or explicit decorative alt.
  @names_check """
  const name = (el) => {
    const labelledby = el.getAttribute('aria-labelledby');
    if (labelledby) {
      return labelledby.split(' ').map((id) => document.getElementById(id)?.textContent || '').join(' ').trim();
    }
    const label = el.getAttribute('aria-label');
    if (label && label.trim()) return label.trim();
    const imgAlt = [...el.querySelectorAll('img[alt]')].map((i) => i.getAttribute('alt')).join('').trim();
    return ((el.textContent || '').replace(/\\s+/g, ' ').trim() + imgAlt).trim();
  };
  // The logo link (an SVG wordmark) is outside this change's scope.
  const unnamed = [...document.querySelectorAll('button, [role="button"], a[href]:not(header nav > div:first-child a)')]
    .filter((el) => !name(el))
    .map((el) => el.outerHTML.slice(0, 120));
  const noAlt = [...document.querySelectorAll('img:not([alt])')].map((i) => i.outerHTML.slice(0, 120));
  return unnamed.length === 0 && noAlt.length === 0 ? 'ok' : JSON.stringify({unnamed, noAlt});
  """

  describe "drop cards at desktop width" do
    @describetag error_path_exemption:
                   "Authorization refusals and sign-in failures are unchanged and covered by visitor_authentication_test."

    setup do
      user = user_fixture(%{github_username: "card_author"})
      drop = drop_fixture(%Drop{}, user, %{title: "Native link drop", body: @body})
      %{user: user, drop: drop}
    end

    @tag viewport: {1280, 800}
    test "the card exposes a visible native link and no scripted click target", %{
      conn: conn,
      drop: drop
    } do
      conn
      |> visit("/")
      |> wait_for_element(".drop-card h2 a")
      |> assert_page("card link", """
      const link = document.querySelector('.drop-card h2 a');
      const item = link.closest('.masonry-item');
      if (link.getAttribute('href') !== '/d/#{drop.short_id}') return 'wrong href ' + link.getAttribute('href');
      if (link.textContent.trim() !== 'Native link drop') return 'link is not named by the title';
      if (item.getAttribute('role') === 'link') return 'item still has role=link';
      if (item.hasAttribute('phx-click')) return 'item still has a scripted click target';
      if (document.querySelector('.drop-card a.hidden')) return 'invisible empty anchor remains';
      const r = link.getBoundingClientRect();
      if (r.width === 0 || r.height === 0) return 'link is not visible';
      return 'ok';
      """)
    end

    @tag viewport: {1280, 800}
    test "modifier-click and middle-click leave this tab; a plain click anywhere on the card opens the Drop",
         %{conn: conn, drop: drop} do
      conn
      |> visit("/")
      |> wait_for_element(".drop-card h2 a")
      |> click_with(".drop-card h2 a", modifiers: ["Control"])
      |> assert_on_root("control-click stays on the list")
      |> click_with(".drop-card h2 a", modifiers: ["Meta"])
      |> assert_on_root("meta-click stays on the list")
      |> click_with(".drop-card h2 a", button: "middle")
      |> assert_on_root("middle-click stays on the list")
      # The card body is covered by the link's stretched hit area, so a pointer
      # click on it (forced, as the target is the link overlay) opens the Drop.
      |> click_with(".drop-card:has(.drop-title a) .drop-body", force: true)
      |> assert_path("/d/#{drop.short_id}")
    end

    @tag viewport: {1280, 800}
    test "keyboard activation opens the Drop", %{conn: conn, drop: drop} do
      conn
      |> visit("/")
      |> wait_for_element(".drop-card h2 a")
      |> assert_page("focus link", """
      const link = document.querySelector('.drop-card h2 a');
      link.focus();
      return document.activeElement === link ? 'ok' : 'link is not focusable';
      """)
      |> press_focused("Enter")
      |> assert_path("/d/#{drop.short_id}")
    end

    @tag viewport: {1280, 800}
    test "card menu actions never navigate the card and aria-expanded follows the menu", %{
      conn: conn,
      drop: drop
    } do
      menu_button = "#drop-card-menu-btn-#{drop.id}"

      conn
      |> visit("/")
      |> wait_for_element(menu_button)
      |> assert_page("menu button semantics", """
      const b = document.querySelector('#{menu_button}');
      if (!b.getAttribute('aria-label')) return 'no aria-label';
      if (b.getAttribute('aria-expanded') !== 'false') return 'initial aria-expanded';
      if (b.getAttribute('aria-controls') !== 'drop-card-menu-#{drop.id}') return 'aria-controls';
      return 'ok';
      """)
      |> click_with(menu_button, [])
      |> assert_page("menu opened", """
      const b = document.querySelector('#{menu_button}');
      const m = document.querySelector('#drop-card-menu-#{drop.id}');
      return b.getAttribute('aria-expanded') === 'true' && getComputedStyle(m).display !== 'none'
        ? 'ok' : 'aria-expanded ' + b.getAttribute('aria-expanded');
      """)
      |> assert_on_root("opening the menu does not navigate")
      |> click_with("#card-copy-link-menu-#{drop.id}", force: true)
      |> assert_on_root("Copy Drop link does not navigate")
      |> click_with("#copy-markdown-#{drop.short_id}", force: true)
      |> assert_on_root("Copy Markdown URL does not navigate")
      |> click_with(menu_button, [])
      |> assert_page("menu closed", """
      const b = document.querySelector('#{menu_button}');
      return b.getAttribute('aria-expanded') === 'false' ? 'ok' : 'aria-expanded ' + b.getAttribute('aria-expanded');
      """)
      |> assert_on_root("closing the menu does not navigate")
    end

    @tag viewport: {1280, 800}
    test "buttons, links and images have names or explicit decorative alt text", %{
      conn: conn,
      drop: drop
    } do
      conn
      |> visit("/")
      |> wait_for_element(".drop-card h2 a")
      |> assert_page("home names", @names_check)
      |> visit("/d/#{drop.short_id}")
      |> wait_for_element("#drop-body")
      |> assert_page("drop page names", @names_check)
    end
  end

  describe "copy actions and clipboard feedback" do
    @describetag error_path_exemption:
                   "Authorization refusals and sign-in failures are unchanged and covered by visitor_authentication_test."

    setup do
      user = user_fixture()
      %{drop: drop_fixture(%Drop{}, user, %{title: "Copy me", body: @body})}
    end

    @tag viewport: {1280, 800}
    test "the copy action is a named button and feedback is announced by a polite live region",
         %{conn: conn, drop: drop} do
      button = "#single-drop-copy-link-#{drop.id}"

      conn
      |> visit("/d/#{drop.short_id}")
      |> wait_for_element(button)
      |> assert_page("copy button + live region", """
      const b = document.querySelector('#{button}');
      const live = document.querySelector('#copy-confirm-message');
      if (!window.liveSocket || !window.liveSocket.isConnected() || !document.querySelector('[data-phx-main].phx-connected')) return 'LiveView not connected yet';
      if (b.tagName !== 'BUTTON' || b.type !== 'button') return 'copy action is not <button type=button>';
      if (!b.getAttribute('aria-label')) return 'copy button has no name';
      if (live.getAttribute('role') !== 'status' || live.getAttribute('aria-live') !== 'polite') return 'not a polite live region';
      if (getComputedStyle(live).display === 'none') return 'live region is display:none and would not announce';
      window.__copySeen = [];
      new MutationObserver(() => {
        if (!live.classList.contains('sr-only')) window.__copySeen.push(live.textContent.trim());
      }).observe(live, {attributes: true, childList: true, subtree: true, characterData: true});
      return 'ok';
      """)
      |> click_with(button, [])
      |> assert_page("feedback follows the real result", """
      await new Promise((r) => setTimeout(r, 50));
      const seen = window.__copySeen.join('|');
      return /Link copied to clipboard|Copy failed/.test(seen) ? 'ok' : 'no feedback shown: ' + seen;
      """)
    end
  end

  describe "copy status starts empty and follows the real clipboard result" do
    @describetag error_path_exemption:
                   "Authorization refusals and sign-in failures are unchanged and covered by visitor_authentication_test."

    setup do
      user = user_fixture()
      %{drop: drop_fixture(%Drop{}, user, %{title: "Copy status", body: @body})}
    end

    for {width, height} <- [{1440, 900}, {390, 844}] do
      @tag viewport: {width, height}
      test "the status is empty until a real copy result at #{width}px", %{
        conn: conn,
        drop: drop
      } do
        button = "#single-drop-copy-link-#{drop.id}"

        conn
        |> visit("/d/#{drop.short_id}")
        |> wait_for_element(button)
        |> assert_page("status is an empty polite live region before any event", """
        if (!window.liveSocket || !window.liveSocket.isConnected() || !document.querySelector('[data-phx-main].phx-connected')) return 'LiveView not connected yet';
        const live = document.querySelector('#copy-confirm-message');
        const text = document.querySelector('#copy-confirm-text');
        if (!live || !text) return 'status or text span missing';
        if (live.getAttribute('role') !== 'status' || live.getAttribute('aria-live') !== 'polite') return 'not a polite live region';
        if (live.hasAttribute('hidden') || live.closest('[hidden], [aria-hidden="true"]')) return 'status is hidden from assistive technology';
        if (getComputedStyle(live).display === 'none') return 'status is display:none';
        if (!live.classList.contains('sr-only')) return 'idle status is not visually hidden';
        if (text.textContent !== '') return 'status has text before any copy: ' + text.textContent;
        if (live.textContent.trim() !== '') return 'status exposes text before any copy: ' + live.textContent.trim();
        window.__copySeen = [];
        window.__copyObserver = new MutationObserver(() => {
          window.__copySeen.push({text: text.textContent, shown: !live.classList.contains('sr-only')});
        });
        window.__copyObserver.observe(live, {attributes: true, childList: true, subtree: true, characterData: true});
        return 'ok';
        """)
        |> assert_page_after("the status stays empty with no copy event", 300, """
        return document.querySelector('#copy-confirm-text').textContent === '' && window.__copySeen.length === 0
          ? 'ok' : 'status changed without a copy event: ' + JSON.stringify(window.__copySeen);
        """)
        |> click_with(button, [])
        |> assert_page("a real success callback reports success", """
        const live = document.querySelector('#copy-confirm-message');
        const shown = window.__copySeen.some((e) => e.text === 'Link copied to clipboard' && e.shown);
        return shown && !live.hasAttribute('hidden') ? 'ok' : 'success not shown: ' + JSON.stringify(window.__copySeen);
        """)
        |> assert_page("the status returns to empty after the visual lifecycle", """
        const live = document.querySelector('#copy-confirm-message');
        return document.querySelector('#copy-confirm-text').textContent === '' && live.classList.contains('sr-only')
          ? 'ok' : 'status not idle: ' + JSON.stringify(window.__copySeen);
        """)
        |> assert_page("the clipboard outcome is made to fail", """
        window.__copySeen = [];
        // ClipboardJS reports an error when the link to copy is empty.
        document.querySelector('#single-drop-copy-link-#{drop.id}').setAttribute('data-clipboard-text', '');
        return 'ok';
        """)
        |> click_with(button, [])
        |> assert_page("a real error callback reports failure, never the earlier success", """
        const live = document.querySelector('#copy-confirm-message');
        const failure = 'Copy failed. Select the link and copy it manually.';
        if (window.__copySeen.some((e) => e.text.includes('Link copied'))) return 'success text shown for a failed copy: ' + JSON.stringify(window.__copySeen);
        const shown = window.__copySeen.some((e) => e.text === failure && e.shown);
        return shown ? 'ok' : 'failure not shown: ' + JSON.stringify(window.__copySeen);
        """)
        |> assert_page("the status is empty again after the failure", """
        const live = document.querySelector('#copy-confirm-message');
        return document.querySelector('#copy-confirm-text').textContent === '' && live.classList.contains('sr-only')
          ? 'ok' : 'status not idle after failure';
        """)
        |> assert_page("a failure right after a success replaces the success", """
        window.__copySeen = [];
        document.querySelector('#single-drop-copy-link-#{drop.id}').setAttribute('data-clipboard-text', 'https://example.test/copy');
        return 'ok';
        """)
        |> click_with(button, [])
        |> assert_page("success is shown first", """
        return window.__copySeen.some((e) => e.text === 'Link copied to clipboard')
          ? 'ok' : 'success not shown: ' + JSON.stringify(window.__copySeen);
        """)
        |> assert_page("the next outcome is a failure", """
        document.querySelector('#single-drop-copy-link-#{drop.id}').setAttribute('data-clipboard-text', '');
        return 'ok';
        """)
        |> click_with(button, [])
        |> assert_page("the latest result is the failure", """
        const nonEmpty = window.__copySeen.map((e) => e.text).filter((t) => t !== '');
        return nonEmpty[nonEmpty.length - 1] === 'Copy failed. Select the link and copy it manually.'
          ? 'ok' : 'latest result is not the failure: ' + JSON.stringify(nonEmpty);
        """)
        |> assert_page("the status ends empty", """
        return document.querySelector('#copy-confirm-text').textContent === '' ? 'ok' : 'status not empty';
        """)
      end
    end
  end

  describe "dialogs" do
    @describetag error_path_exemption:
                   "Authorization refusals and sign-in failures are unchanged and covered by visitor_authentication_test."

    setup do
      user = user_fixture()
      drop_fixture(%Drop{}, user, %{title: "Dialog drop", body: @body})
      :ok
    end

    @tag viewport: {1280, 800}
    test "the sign-in popup is a modal dialog with focus, Escape and focus return", %{conn: conn} do
      conn
      |> visit("/")
      |> wait_for_element("#create-drop-button")
      |> click_with("#create-drop-button", [])
      |> assert_page("dialog open", """
      const d = document.querySelector('#signin-popup-message');
      if (d.getAttribute('role') !== 'dialog' || d.getAttribute('aria-modal') !== 'true') return 'role/aria-modal';
      const title = document.getElementById(d.getAttribute('aria-labelledby'));
      if (!title || !title.textContent.trim()) return 'no accessible name';
      if (getComputedStyle(d).display === 'none') return 'dialog not shown';
      if (!d.contains(document.activeElement)) return 'initial focus is outside the dialog';
      return 'ok';
      """)
      |> press_focused("Tab")
      |> press_focused("Tab")
      |> press_focused("Tab")
      |> press_focused("Tab")
      |> assert_page("focus is contained", """
      const d = document.querySelector('#signin-popup-message');
      return d.contains(document.activeElement) ? 'ok' : 'focus escaped to ' + document.activeElement.outerHTML.slice(0, 80);
      """)
      |> press_focused("Escape")
      |> assert_page("closed and focus returned", """
      const d = document.querySelector('#signin-popup-message');
      if (getComputedStyle(d).display !== 'none') return 'dialog still shown';
      return document.activeElement && document.activeElement.id === 'create-drop-button'
        ? 'ok' : 'focus not returned to the trigger: ' + document.activeElement.outerHTML.slice(0, 80);
      """)
    end

    @tag viewport: {1280, 800}
    test "click-away still closes the sign-in popup", %{conn: conn} do
      conn
      |> visit("/")
      |> wait_for_element("#create-drop-button")
      |> click_with("#create-drop-button", [])
      |> click_with("header .nav-primary", position: %{x: 5, y: 5}, force: true)
      |> assert_page("closed", """
      return getComputedStyle(document.querySelector('#signin-popup-message')).display === 'none' ? 'ok' : 'still open';
      """)
    end
  end

  describe "search suggestions" do
    @describetag error_path_exemption:
                   "Authorization refusals and sign-in failures are unchanged and covered by visitor_authentication_test."

    setup do
      user = user_fixture(%{github_username: "searcher"})
      drop_fixture(%Drop{}, user, %{title: "Searchable drop", body: @body})
      search_history_fixture(%{user_id: user.id, query: "alpha query"})
      search_history_fixture(%{user_id: user.id, query: "beta query"})
      %{user: user}
    end

    @tag viewport: {1280, 800}
    test "arrow keys select options, Enter activates one, Escape closes the list", %{
      conn: conn,
      user: user
    } do
      input = "#desktop-search-query"

      conn
      |> sign_in_user(user)
      |> visit("/")
      |> wait_for_element(input)
      |> click_with(input, [])
      |> wait_for_element("#navbar-search-dropdown")
      |> assert_page("listbox semantics", """
      const list = document.querySelector('#navbar-search-dropdown [role="listbox"]');
      const options = [...document.querySelectorAll('#navbar-search-dropdown [role="option"]')];
      if (!list || options.length < 2) return 'listbox/options missing';
      if (options.some((o) => o.getAttribute('tabindex') === '0')) return 'option is a tabindex=0 div';
      const input = document.querySelector('#{input}');
      if (input.getAttribute('aria-expanded') !== 'true') return 'combobox not expanded';
      return 'ok';
      """)
      |> press_focused("ArrowDown")
      |> assert_page("first option selected", """
      const options = [...document.querySelectorAll('#navbar-search-dropdown [role="option"]')];
      const input = document.querySelector('#{input}');
      return options[0].getAttribute('aria-selected') === 'true' && input.getAttribute('aria-activedescendant') === options[0].id
        ? 'ok' : 'first option not selected';
      """)
      |> press_focused("ArrowDown")
      |> press_focused("ArrowUp")
      |> assert_page("selection moved down then up", """
      const options = [...document.querySelectorAll('#navbar-search-dropdown [role="option"]')];
      const selected = options.filter((o) => o.getAttribute('aria-selected') === 'true');
      return selected.length === 1 && selected[0] === options[0] ? 'ok' : 'selection is ' + selected.map((o) => o.id);
      """)
      |> press_focused("Escape")
      |> assert_page("escape closed the list", """
      return document.querySelector('#navbar-search-dropdown') ? 'dropdown still open' : 'ok';
      """)
      # ArrowDown reopens the list; a second ArrowDown selects the first option.
      |> press_focused("ArrowDown")
      |> wait_for_element("#navbar-search-dropdown")
      |> press_focused("ArrowDown")
      |> press_focused("Enter")
      |> assert_page("enter activated the selected suggestion", """
      return /[?&]q=/.test(location.search) ? 'ok' : 'search not submitted: ' + location.href;
      """)
    end

    @tag viewport: {1280, 800}
    test "the history delete button is named and becomes visible on focus", %{
      conn: conn,
      user: user
    } do
      conn
      |> sign_in_user(user)
      |> visit("/")
      |> wait_for_element("#desktop-search-query")
      |> click_with("#desktop-search-query", [])
      |> wait_for_element("#navbar-search-dropdown button")
      |> assert_page("delete button", """
      const b = document.querySelector('#navbar-search-dropdown button');
      if (!b.getAttribute('aria-label')) return 'no aria-label';
      document.querySelector('#desktop-search-query').blur();
      document.activeElement.blur();
      const before = getComputedStyle(b).opacity;
      b.focus();
      const after = getComputedStyle(b).opacity;
      return before === '0' && after === '1' ? 'ok' : 'opacity before=' + before + ' after=' + after;
      """)
      |> press_focused("Escape")
      |> assert_page("Escape from the list closes it and returns focus to the field", """
      if (document.querySelector('#navbar-search-dropdown')) return 'dropdown still open';
      return document.activeElement.id === 'desktop-search-query' ? 'ok' : 'focus is on ' + document.activeElement.outerHTML.slice(0, 80);
      """)
    end
  end

  describe "header triggers at 390px width" do
    @describetag error_path_exemption:
                   "Authorization refusals and sign-in failures are unchanged and covered by visitor_authentication_test."

    setup do
      user = user_fixture(%{github_username: "phone_user"})
      drop_fixture(%Drop{}, user, %{title: "Phone drop", body: @body})
      %{user: user}
    end

    @tag viewport: {390, 844}
    test "account, notification and search triggers are named buttons that report state", %{
      conn: conn,
      user: user
    } do
      conn
      |> sign_in_user(user)
      |> visit("/")
      |> resize_window(390, 844)
      |> wait_for_element("#account-menu-trigger")
      |> assert_page("no horizontal overflow", """
      return document.documentElement.scrollWidth <= window.innerWidth ? 'ok' : 'page is wider than the viewport';
      """)
      |> assert_page("trigger semantics", """
      for (const sel of ['#account-menu-trigger', '#notifications-trigger-mobile', '#search-trigger']) {
        const b = document.querySelector(sel);
        if (b.tagName !== 'BUTTON') return sel + ' is not a <button>';
        if (!b.getAttribute('aria-label')) return sel + ' has no name';
        if (b.getAttribute('aria-expanded') !== 'false') return sel + ' initial aria-expanded';
      }
      return 'ok';
      """)
      |> click_with("#notifications-trigger-mobile", [])
      |> assert_page("notifications open", """
      const b = document.querySelector('#notifications-trigger-mobile');
      return b.getAttribute('aria-expanded') === 'true' && getComputedStyle(document.querySelector('#notifications-container')).display !== 'none'
        ? 'ok' : 'notification state ' + b.getAttribute('aria-expanded');
      """)
      |> click_with("#close-notifications", [])
      |> assert_page("notifications closed", """
      const b = document.querySelector('#notifications-trigger-mobile');
      return b.getAttribute('aria-expanded') === 'false' ? 'ok' : 'notification state ' + b.getAttribute('aria-expanded');
      """)
      |> click_with("#account-menu-trigger", [])
      |> assert_page("account menu open", """
      const b = document.querySelector('#account-menu-trigger');
      return b.getAttribute('aria-expanded') === 'true' && getComputedStyle(document.querySelector('#slide-menu')).display !== 'none'
        ? 'ok' : 'account state ' + b.getAttribute('aria-expanded');
      """)
      |> click_with("#account-menu-trigger", [])
      |> assert_page("account menu closed", """
      const b = document.querySelector('#account-menu-trigger');
      return b.getAttribute('aria-expanded') === 'false' && getComputedStyle(document.querySelector('#slide-menu')).display === 'none'
        ? 'ok' : 'account state ' + b.getAttribute('aria-expanded');
      """)
      |> click_with("#search-trigger", [])
      |> assert_page("search overlay open", """
      const b = document.querySelector('#search-trigger');
      const input = document.querySelector('#search-overlay input[name="query"]');
      if (b.getAttribute('aria-expanded') !== 'true') return 'search aria-expanded ' + b.getAttribute('aria-expanded');
      return document.activeElement === input ? 'ok' : 'focus is not in the search field';
      """)
      |> press_focused("Escape")
      |> assert_page("search overlay closed and focus returned", """
      const b = document.querySelector('#search-trigger');
      if (getComputedStyle(document.querySelector('#search-overlay')).display !== 'none') return 'overlay still open';
      if (b.getAttribute('aria-expanded') !== 'false') return 'search aria-expanded ' + b.getAttribute('aria-expanded');
      return document.activeElement === b ? 'ok' : 'focus not returned to the trigger';
      """)
      |> assert_page("names at 390px", @names_check)
    end
  end
end
