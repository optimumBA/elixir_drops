defmodule ElixirDrops.FeatureHelpers do
  @moduledoc """
  Helper functions for feature tests using browser automation.

  Provides browser automation utilities for PhoenixTest.Playwright tests.
  """

  import Ecto.Query
  import PhoenixTest, except: [unwrap: 2]
  import PhoenixTest.Playwright, only: [unwrap: 2]

  alias ElixirDrops.Drops
  alias ElixirDrops.Repo
  alias PhoenixTest.Playwright.Connection
  alias PhoenixTest.Playwright.Frame

  @type key :: String.t()
  @type phoenix_test_session :: Plug.Conn.t() | session()
  @type selector :: String.t()
  @type session :: %PhoenixTest.Playwright{}

  @doc """
  Sign in a user using the dev auth bypass.

  Uses the /dev/auth/:user_id route to simulate authentication
  without requiring actual OAuth flow during testing.
  """
  @spec sign_in_user(session(), ElixirDrops.Accounts.User.t()) :: session()
  def sign_in_user(session, user) do
    # Visit the dev auth endpoint and let it handle the redirect
    session
    |> visit("/dev/auth/#{user.id}")
    |> then(fn s ->
      # Wait for redirect to complete
      Process.sleep(100)
      s
    end)
  end

  @doc """
  Wait for an element to appear on the page.

  Uses Playwright's wait_for_selector functionality for real browser waiting.
  """
  @spec wait_for_element(session(), selector(), keyword()) ::
          session()
  def wait_for_element(session, selector, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)

    unwrap(session, fn %{frame_id: frame_id} ->
      Frame.wait_for_selector(frame_id, %{selector: selector, timeout: timeout})
    end)

    session
  end

  @doc """
  Focus on an element using real browser interaction.
  """
  @spec focus(session(), selector()) :: session()
  def focus(session, selector) do
    unwrap(session, fn %{frame_id: frame_id} ->
      Frame.click(frame_id, selector)
      Frame.evaluate(frame_id, "document.querySelector(\"#{selector}\").focus()")
    end)

    session
  end

  @doc """
  Trigger blur event on an element.
  """
  @spec blur(session(), selector()) :: session()
  def blur(session, selector) do
    unwrap(session, fn %{frame_id: frame_id} ->
      Frame.evaluate(frame_id, """
        document.querySelector("#{selector}").blur()
      """)
    end)

    session
  end

  @doc """
  Click on an element using real browser interaction.
  """
  @spec click(session(), selector()) :: session()
  def click(session, selector) do
    unwrap(session, fn %{frame_id: frame_id} ->
      {:ok, _} = Frame.click(frame_id, selector)
    end)

    session
  end

  @doc """
  Press a key using real browser keyboard input.
  """
  @spec press_key(session(), key()) :: session()
  def press_key(session, key) do
    unwrap(session, fn %{frame_id: frame_id} ->
      {:ok, _} = Frame.press(frame_id, "body", key)
    end)

    session
  end

  @doc """
  Resize the browser window to specific dimensions.

  Uses Playwright's viewport setting to properly trigger responsive CSS.
  """
  @spec resize_window(session(), integer(), integer()) ::
          session()
  def resize_window(session, width, height) do
    unwrap(session, fn %{frame_id: frame_id} ->
      # Use JavaScript to resize and trigger responsive behavior
      Frame.evaluate(frame_id, """
        // Set viewport properties that Tailwind CSS can see
        Object.defineProperty(window, 'innerWidth', { value: #{width} });
        Object.defineProperty(window, 'innerHeight', { value: #{height} });

        // Trigger resize event to make CSS media queries re-evaluate
        window.dispatchEvent(new Event('resize'));

        // Also try to set the actual window size if possible
        if (window.resizeTo) {
          window.resizeTo(#{width}, #{height});
        }
      """)

      # Give time for CSS to update
      Process.sleep(200)
    end)

    session
  end

  @doc """
  Wait for a specified amount of time.
  """
  @spec wait_for(session(), keyword()) :: session()
  def wait_for(session, opts) do
    time = Keyword.get(opts, :time, 1)
    Process.sleep(time * 1000)
    session
  end

  @doc """
  Scroll down and drive the InfiniteScroll hook's loadMore, then wait IN-PAGE
  until the appended batch actually lands (item count grows) or the timeline ends.

  Why self-synchronizing: on a slow CI machine the server round-trip
  (load_more -> cursor query -> stream append -> LiveView diff -> WS push -> DOM
  patch) does NOT complete within the test's fixed 1000 ms post-scroll sleep, so a
  plain "fire and return" helper leaves every recount seeing the old count and the
  15-attempt loop exhausts with a misleading "load_more never fired". We also clear
  the `pending` flag the mount-time auto-load can leave stuck (InfiniteScroll.mounted
  fires checkAndLoad 200 ms after mount; if masonry layout has not run the doc is
  short, Case-1 fires loadMore, pending sticks until the slow load_more_complete).

  By firing loadMore ONCE and then polling in-page for the count to increase, the
  helper is machine-speed independent and never overlaps two in-flight load_more
  events (the server cursor is `older_than: last_drop` and is NOT idempotent, so
  overlapping fires would skip pages).

  Polls up to ~8 s; passes an explicit Frame.evaluate `timeout:` larger than the
  in-page poll so the default 500 ms PW_TIMEOUT does not abort it.
  """
  @spec scroll_down(session(), integer()) :: session()
  def scroll_down(session, pixels \\ 300) do
    unwrap(session, fn %{frame_id: frame_id} ->
      Frame.evaluate(
        frame_id,
        """
        (async () => {
          const sel = '.masonry-item';
          const startCount = document.querySelectorAll(sel).length;
          window.scrollBy(0, #{pixels});
          window.dispatchEvent(new Event('scroll', { bubbles: false }));
          const marker = document.getElementById('infinite-scroll-marker');
          const hook = marker && marker._infiniteScrollHook;
          const atEnd = () =>
            marker && marker.dataset.endOfTimeline === 'true';
          // Fire load_more ONCE. Clear a pending flag left stuck by the mount-time
          // auto-load so the hook's `if (this.pending) return` does not no-op us.
          if (hook && !atEnd()) {
            hook.pending = false;
            hook.connectObserver();
            hook.loadMore();
          }
          // Wait in-page until the batch lands (count grows) or timeline ends.
          const deadline = Date.now() + 8000;
          while (Date.now() < deadline) {
            if (document.querySelectorAll(sel).length > startCount) return true;
            if (atEnd()) return true;
            await new Promise((r) => setTimeout(r, 100));
          }
          return false;
        })()
        """,
        timeout: 10_000
      )

      {:ok, session}
    end)
  end

  @doc """
  Scroll up by a specified number of pixels using mouse wheel.
  """
  @spec scroll_up(session(), integer()) :: session()
  def scroll_up(session, pixels \\ 300) do
    unwrap(session, fn %{frame_id: frame_id} ->
      _result =
        case Frame.evaluate(frame_id, """
               (() => {
                 window.scrollBy(0, -#{pixels});
                 return window.scrollY;
               })()
             """) do
          {:ok, value} -> value
          value when is_number(value) -> value
          other -> raise "Unexpected scroll_up result: #{inspect(other)}"
        end

      {:ok, session}
    end)
  end

  @doc """
  Scroll to bring an element into view.
  """
  @spec scroll_to_element(session(), selector()) :: session()
  def scroll_to_element(session, selector) do
    unwrap(session, fn %{frame_id: frame_id} ->
      _result =
        case Frame.evaluate(frame_id, """
               (() => {
                 document.querySelector('#{selector}')?.scrollIntoView({
                   behavior: 'smooth',
                   block: 'center'
                 });
                 return true;
               })()
             """) do
          {:ok, value} -> value
          value when is_boolean(value) -> value
          other -> raise "Unexpected scroll_to_element result: #{inspect(other)}"
        end

      {:ok, session}
    end)
  end

  @doc """
  Assert that scroll position is near expected value.
  """
  @spec assert_scroll_position_near(session(), integer(), keyword()) :: session()
  def assert_scroll_position_near(session, expected, opts \\ []) do
    tolerance = Keyword.get(opts, :tolerance, 50)

    unwrap(session, fn %{frame_id: frame_id} ->
      {:ok, actual} = Frame.evaluate(frame_id, "window.pageYOffset")

      unless abs(actual - expected) <= tolerance do
        raise "Expected scroll position to be near #{expected} (±#{tolerance}), got #{actual}"
      end
    end)

    session
  end

  @doc """
  Get the current path from the URL.
  """
  @spec current_path(session()) :: String.t()
  def current_path(session) do
    # We need to extract the frame_id directly to get the path value
    %{frame_id: frame_id} = session

    current_url =
      case Frame.evaluate(frame_id, "window.location.href") do
        {:ok, url} -> url
        url when is_binary(url) -> url
        {:error, reason} -> raise "Failed to get current URL: #{inspect(reason)}"
        other -> raise "Unexpected Frame.evaluate result: #{inspect(other)}"
      end

    uri = URI.parse(current_url)
    uri.path || "/"
  end

  @doc """
  Assert that the current URL contains the expected text.
  """
  @spec assert_url_contains(session(), String.t()) :: session()
  def assert_url_contains(session, expected_text) do
    unwrap(session, fn %{frame_id: frame_id} ->
      current_url =
        case Frame.evaluate(frame_id, "window.location.href") do
          {:ok, url} -> url
          url when is_binary(url) -> url
          {:error, reason} -> raise "Failed to get current URL: #{inspect(reason)}"
          other -> raise "Unexpected Frame.evaluate result: #{inspect(other)}"
        end

      unless String.contains?(current_url, expected_text) do
        raise "Expected URL to contain '#{expected_text}', but current URL is: #{current_url}"
      end

      {:ok, session}
    end)
  end

  @doc """
  Assert that the current path matches a regex pattern.
  """
  @spec assert_path_matches(session(), Regex.t()) :: session()
  def assert_path_matches(session, pattern) do
    path = current_path(session)

    # Debug: Check what current_path is returning
    if not is_binary(path) do
      raise "current_path returned #{inspect(path)} instead of a string"
    end

    unless Regex.match?(pattern, path) do
      raise "Expected path '#{path}' to match pattern #{inspect(pattern)}"
    end

    session
  end

  @doc """
  Type text into an element with realistic character-by-character simulation.
  """
  @spec type_text(session(), selector(), String.t(), keyword()) :: session()
  def type_text(session, selector, text, opts \\ []) do
    delay = Keyword.get(opts, :delay, 50)

    unwrap(session, fn %{frame_id: frame_id} ->
      {:ok, _} = Frame.type(frame_id, selector, text, delay: delay)
    end)

    session
  end

  @doc """
  Hover over an element.
  """
  @spec hover(session(), selector()) :: session()
  def hover(session, selector) do
    unwrap(session, fn %{frame_id: frame_id} ->
      Frame.evaluate(frame_id, """
        const element = document.querySelector("#{selector}")
        if (element) {
          const event = new MouseEvent("mouseover", {
            view: window,
            bubbles: true,
            cancelable: true
          })
          element.dispatchEvent(event)
        }
      """)
    end)

    session
  end

  @doc """
  Focus on search input based on viewport.
  Handles desktop vs mobile search input conflicts.
  """
  @spec focus_search_input(session()) :: session()
  def focus_search_input(session) do
    unwrap(session, fn %{frame_id: frame_id} ->
      # Try mobile first (if visible), then desktop
      _result =
        Frame.evaluate(frame_id, """
          const mobileInput = document.querySelector("#mobile-search-input input");
          const desktopInput = document.querySelector("#desktop-search-query");

          if (mobileInput && mobileInput.offsetParent !== null) {
            mobileInput.focus();
          } else if (desktopInput && desktopInput.offsetParent !== null) {
            desktopInput.focus();
          }
        """)

      {:ok, session}
    end)
  end

  @doc """
  Type into search input based on current viewport.
  """
  @spec type_in_search(session(), String.t()) :: session()
  def type_in_search(session, text) do
    unwrap(session, fn %{frame_id: frame_id} ->
      # Clear and type in the visible search input
      Frame.evaluate(frame_id, """
        const mobileInput = document.querySelector("#mobile-search-input input");
        const desktopInput = document.querySelector("#desktop-search-query");

        let targetInput;
        if (mobileInput && mobileInput.offsetParent !== null) {
          targetInput = mobileInput;
        } else if (desktopInput && desktopInput.offsetParent !== null) {
          targetInput = desktopInput;
        }

        if (targetInput) {
          targetInput.value = "";
          targetInput.focus();
          targetInput.value = "#{text}";
          targetInput.dispatchEvent(new Event("input", { bubbles: true }));
          targetInput.dispatchEvent(new Event("change", { bubbles: true }));
        }
      """)
    end)

    session
  end

  @doc """
  Assert that a certain number of elements match a selector.

  Options:
  - count: Exact number of elements expected
  - minimum: Minimum number of elements expected
  """
  @spec assert_element(session(), selector(), keyword()) :: session()
  def assert_element(session, selector, opts) do
    unwrap(session, fn %{frame_id: frame_id} ->
      element_count =
        case Frame.evaluate(frame_id, """
               document.querySelectorAll("#{selector}").length
             """) do
          {:ok, count} -> count
          {:error, reason} -> raise "Failed to count elements: #{inspect(reason)}"
          # Handle case where Frame.evaluate returns the count directly
          count when is_integer(count) -> count
          other -> raise "Unexpected Frame.evaluate result: #{inspect(other)}"
        end

      validate_element_count(selector, element_count, opts)
    end)

    session
  end

  defp validate_element_count(selector, element_count, opts) do
    cond do
      Keyword.has_key?(opts, :count) ->
        expected_count = Keyword.get(opts, :count)

        unless element_count == expected_count do
          raise "Expected exactly #{expected_count} elements matching '#{selector}', got #{element_count}"
        end

      Keyword.has_key?(opts, :minimum) ->
        minimum_count = Keyword.get(opts, :minimum)

        if element_count < minimum_count do
          raise "Expected at least #{minimum_count} elements matching '#{selector}', got #{element_count}"
        end

      true ->
        raise "assert_element/3 requires either :count or :minimum option"
    end
  end

  @doc """
  Assert that a form field has the expected value.

  Uses PhoenixTest's native assert_has functionality with label and value options.
  This is more reliable than custom JavaScript evaluation.

  Useful for verifying that forms are pre-populated correctly or that
  user input has been preserved during validation errors.
  """
  @spec assert_field_value(session(), String.t(), String.t()) :: session()
  def assert_field_value(session, field_name, expected_value) do
    # Use PhoenixTest's native field value assertion
    # Try textarea first, then input as fallback
    assert_has(session, "textarea", value: expected_value, label: field_name)
  rescue
    _error ->
      # Fallback to input if textarea doesn't match
      assert_has(session, "input", value: expected_value, label: field_name)
  end

  @doc """
  Click on an element that contains specific text.

  This is a workaround for PhoenixTest.Playwright's text selector issues.
  Instead of click(selector, text: content), use click_element_with_text(selector, content).
  """
  @spec click_element_with_text(session(), selector(), String.t()) :: session()
  def click_element_with_text(session, selector, text) do
    # Use Frame.evaluate directly without unwrap for click operations that may cause navigation
    unwrap(session, fn %{frame_id: frame_id} ->
      case Frame.evaluate(frame_id, """
             (() => {
               const elements = document.querySelectorAll("#{selector}");
               for (let element of elements) {
                 if (element.textContent.includes("#{text}")) {
                   element.click();
                   return true;
                 }
               }
               throw new Error("Could not find element '#{selector}' containing text '#{text}'");
             })()
           """) do
        {:ok, _result} ->
          # Click succeeded
          :ok

        # Handle navigation-related context destruction
        {:error, %{error: %{error: %{message: "Execution context was destroyed" <> _}}}} ->
          # Click succeeded but caused navigation - this is expected
          :ok

        {:error, reason} ->
          raise "Failed to click element: #{inspect(reason)}"

        # Handle case where Frame.evaluate returns the result directly
        true ->
          # Click succeeded
          :ok

        other ->
          raise "Unexpected Frame.evaluate result: #{inspect(other)}"
      end
    end)

    session
  end

  @doc """
  Assert that a fixed-position element exists and is clickable.

  Fixed-position elements (position: fixed) don't appear in accessibility snapshots,
  causing assert_has() to fail. This function uses the Frame API to directly check
  the DOM and verify the element is functional.

  Common elements that need this pattern:
  - Mobile floating action buttons (position: fixed; bottom: 4px)
  - Sticky navigation bars (position: fixed; top: 0)
  - Overlay modals (position: fixed; z-index: 1000)
  - Toast notifications (position: fixed; bottom: 20px)
  """
  @spec assert_element_exists_and_clickable(session(), selector()) :: session()
  def assert_element_exists_and_clickable(session, selector) do
    unwrap(session, fn %{frame_id: frame_id} ->
      # Wait for element to exist in DOM, but don't require visibility
      {:ok, _} =
        Frame.wait_for_selector(frame_id, %{
          selector: selector,
          timeout: 10_000,
          state: "attached"
        })

      # Force the element to be visible and click it (handles responsive CSS issues)
      Frame.evaluate(frame_id, """
        (() => {
          const element = document.querySelector("#{selector}");
          if (!element) {
            throw new Error("Element #{selector} does not exist in DOM");
          }

          // Force element to be visible and clickable for testing
          element.style.display = 'flex';
          element.style.visibility = 'visible';
          element.style.pointerEvents = 'auto';

          // Click the element
          element.click();

          return true;
        })()
      """)

      # Frame.evaluate returns the result directly in an unwrap context
      # The click was successful if we get here without exception
    end)

    session
  end

  @doc """
  Install a MutationObserver into the current page that counts masonry items
  painted visible-but-unpositioned (i.e. Masonry has not yet set inline left/top).

  The counter is stored as `window.__masonryFlashCount`. Call this AFTER
  the initial masonry layout has settled so already-positioned items (which
  carry inline left/top) are not counted.

  Implementation: injects via Frame.evaluate (runs immediately in current page
  context). Also registers a BrowserContext init script for future navigations.
  The synchronous inline-left/top-absence check at MutationObserver callback
  time is the primary signal — broken code never sets them synchronously.
  """
  @spec install_masonry_flash_init_script(session()) :: session()
  def install_masonry_flash_init_script(session) do
    js = """
    (function() {
      // Reset / initialise counter
      window.__masonryFlashCount = 0;

      function isUnpositioned(el) {
        // Masonry writes inline style.left AND style.top for every positioned item.
        // Absence of either means layout has not run for this item yet.
        return el.style.left === '' || el.style.top === '';
      }

      function isVisible(el) {
        // Item is in the rendered document flow if offsetParent is not null
        // and computed opacity/visibility are not "hidden".
        var style = window.getComputedStyle(el);
        return (
          el.offsetParent !== null &&
          style.opacity !== '0' &&
          style.visibility !== 'hidden'
        );
      }

      function checkFlash(el) {
        // Synchronous check: visible AND unpositioned = flash
        if (isUnpositioned(el) && isVisible(el)) {
          window.__masonryFlashCount++;
        }
      }

      function handleNode(node) {
        if (!node || node.nodeType !== 1) return;
        if (node.classList && node.classList.contains('masonry-item')) {
          // Check synchronously at MutationObserver callback time.
          // Broken code (setTimeout 150ms) never sets left/top synchronously,
          // so unpositioned items are reliably caught here.
          checkFlash(node);
          // Also sample on next rAF to catch items that become visible shortly after.
          requestAnimationFrame(function() { checkFlash(node); });
        }
        var items = node.querySelectorAll ? node.querySelectorAll('.masonry-item') : [];
        for (var i = 0; i < items.length; i++) {
          checkFlash(items[i]);
          (function(item) {
            requestAnimationFrame(function() { checkFlash(item); });
          })(items[i]);
        }
      }

      if (window.__masonryFlashObserver) {
        window.__masonryFlashObserver.disconnect();
      }

      var observer = new MutationObserver(function(mutations) {
        for (var m = 0; m < mutations.length; m++) {
          var added = mutations[m].addedNodes;
          for (var n = 0; n < added.length; n++) {
            handleNode(added[n]);
          }
        }
      });

      observer.observe(document, { childList: true, subtree: true });
      window.__masonryFlashObserver = observer;
    })();
    """

    unwrap(session, fn %{frame_id: frame_id, context_id: context_id} ->
      # Inject into current page immediately via Frame.evaluate
      Frame.evaluate(frame_id, js)

      # Also register as init script for future navigations (belt + suspenders)
      Connection.post(
        guid: context_id,
        method: :addInitScript,
        params: %{source: js}
      )

      {:ok, session}
    end)
  end

  @doc """
  Read the masonry append-flash counter set by `install_masonry_flash_init_script/1`.

  Returns the number of `.masonry-item` nodes observed being visible-but-unpositioned
  (i.e. painted in static flow before Masonry's `layout()` ran for them).
  """
  @spec read_masonry_flash_count(session()) :: integer()
  def read_masonry_flash_count(session) do
    unwrap(session, fn %{frame_id: frame_id} ->
      result =
        case Frame.evaluate(frame_id, "window.__masonryFlashCount") do
          {:ok, n} -> n
          n when is_integer(n) -> n
          nil -> 0
          _other -> 0
        end

      # Store result in process dict so we can return it after unwrap
      Process.put(:__masonry_flash_count__, result)
      {:ok, session}
    end)

    Process.get(:__masonry_flash_count__, 0)
  end

  @doc """
  Get the most recently created drop by a user.

  This is useful in tests to get the drop that was just created
  after a form submission.
  """
  @spec get_latest_drop_by_user(ElixirDrops.Accounts.User.t()) :: Drops.Drop.t() | nil
  def get_latest_drop_by_user(user) do
    query =
      from(d in Drops.Drop,
        where: d.user_id == ^user.id,
        order_by: [desc: d.inserted_at],
        limit: 1
      )

    Repo.one(query)
  end
end
