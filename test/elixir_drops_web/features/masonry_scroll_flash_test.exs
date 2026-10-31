defmodule ElixirDropsWeb.Features.MasonryScrollFlashTest do
  @moduledoc """
  Regression test: appended masonry items must never be painted visible-but-unpositioned.

  ROOT CAUSE: masonry.js updated() defers append work behind setTimeout(150).
  For >= 150 ms the appended .masonry-item nodes render in static document flow
  (stacked, full container width) with no inline left/top set by Masonry.

  FIX: synchronously add masonry-item-pending (opacity:0; visibility:hidden) to
  each new item in updated(), swap setTimeout(150) -> requestAnimationFrame, and
  remove masonry-item-pending on a double-rAF after masonry.layout() completes.

  METRIC: window.__masonryFlashCount (set by install_masonry_flash_init_script/1).
  Counts each .masonry-item observed visible (offsetParent != null, opacity != 0,
  visibility != hidden) while having no inline style.left/style.top (unpositioned).
  Pass: flashed == 0.
  """

  # Measures paint timing while browser rendering and scrolling are active.
  use ElixirDropsWeb.FeatureCase, async: false

  import ElixirDrops.FeatureHelpers

  alias PhoenixTest.Playwright.Connection
  alias PhoenixTest.Playwright.Frame
  alias PhoenixTest.Playwright.Serialization

  @moduletag :feature
  @moduletag timeout: 120_000

  describe "infinite scroll append does not flash unpositioned items" do
    setup do
      user = user_fixture(%{github_id: 99_001, github_username: "flashtest_user"})
      # Seed >= 3 max-batches so scrolling guarantees at least one load_more.
      # create_multiple_drops uses screenshot.status: :completed, internal_url: nil
      # -> passes mount filter AND no real <img> so imagesLoaded resolves immediately.
      create_multiple_drops(user, 45)

      %{user: user}
    end

    test "no masonry item is painted visible-but-unpositioned during infinite-scroll append",
         %{conn: conn, user: user} do
      # 1. Sign in and visit homepage
      session =
        conn
        |> sign_in_user(user)
        |> visit("/")

      # 2. Wait for initial batch to render and masonry to settle
      ready_session = wait_for_element(session, ".masonry-item")
      assert wait_for_masonry_layout(ready_session)

      # 3. Arm the flash counter AFTER initial masonry-ready so already-positioned
      #    items (carrying inline left/top) don't register as flashes.
      armed_session = install_masonry_flash_init_script(ready_session)

      # 4. Record initial item count, then scroll until a new batch appends.
      initial_count = count_masonry_items(armed_session)

      scrolled_session = scroll_until_more_items(armed_session, initial_count, 15, 3000)

      # 5. Wait until the appended items are positioned and revealed.
      assert wait_for_masonry_layout(scrolled_session)

      # 6. PRIMARY ASSERTION: no item was visible-but-unpositioned at append time.
      flashed = read_masonry_flash_count(scrolled_session)

      assert flashed == 0,
             "#{flashed} appended masonry item(s) painted visible-but-unpositioned (static flow) " <>
               "before masonry.layout() ran — append flash regression"

      # 7. SECONDARY GUARD: all items now have positive height (settled state).
      all_have_height =
        evaluate_js(scrolled_session, """
          (() => {
            const items = document.querySelectorAll('.masonry-item');
            for (let item of items) {
              if (item.offsetHeight <= 0) return false;
            }
            return items.length > 0;
          })()
        """)

      assert all_have_height,
             "Some .masonry-item elements have zero height after layout settled"

      # 8. SECONDARY GUARD: no two items share the same rounded top-left position
      #    (proves items ARE positioned by Masonry after append).
      duplicate_position =
        evaluate_js(scrolled_session, """
          (() => {
            const items = document.querySelectorAll('.masonry-item');
            const seen = new Set();
            for (let item of items) {
              const rect = item.getBoundingClientRect();
              const key = Math.round(rect.top) + ',' + Math.round(rect.left);
              if (seen.has(key)) return true;
              seen.add(key);
            }
            return false;
          })()
        """)

      refute duplicate_position,
             "Two or more .masonry-item elements share the same top-left position — " <>
               "Masonry layout did not run for appended items"
    end
  end

  # --- Private helpers -------------------------------------------------------

  defp scroll_until_more_items(_session, _initial, 0, _px) do
    raise "load_more never fired after repeated scrolling — " <>
            "seed more drops or increase scroll attempts"
  end

  defp scroll_until_more_items(session, initial_count, attempts, px) do
    session = scroll_down(session, px)

    if wait_for_browser_condition(
         session,
         "() => document.querySelectorAll('.masonry-item').length > #{initial_count}",
         1000
       ) do
      session
    else
      scroll_until_more_items(session, initial_count, attempts - 1, px)
    end
  end

  defp wait_for_masonry_layout(session) do
    wait_for_browser_condition(
      session,
      "() => [...document.querySelectorAll('.masonry-item')].every(item => item.style.left && item.style.top && !item.classList.contains('masonry-item-pending'))",
      10_000
    )
  end

  defp wait_for_browser_condition(session, expression, timeout) do
    unwrap(session, fn %{frame_id: frame_id} ->
      response =
        Connection.post(
          guid: frame_id,
          method: :wait_for_function,
          params: %{
            expression: expression,
            is_function: true,
            arg: Serialization.serialize_arg(nil),
            timeout: timeout
          }
        )

      Process.put(:__condition_met__, not Map.has_key?(response, :error))
    end)

    Process.get(:__condition_met__)
  end

  defp count_masonry_items(session) do
    unwrap(session, fn %{frame_id: frame_id} ->
      result =
        case Frame.evaluate(frame_id, "document.querySelectorAll('.masonry-item').length") do
          {:ok, n} -> n
          n when is_integer(n) -> n
          _other -> 0
        end

      Process.put(:__item_count__, result)
      {:ok, session}
    end)

    Process.get(:__item_count__, 0)
  end

  defp evaluate_js(session, js) do
    unwrap(session, fn %{frame_id: frame_id} ->
      result =
        case Frame.evaluate(frame_id, js) do
          {:ok, value} -> value
          value when is_boolean(value) -> value
          _other -> nil
        end

      Process.put(:__js_result__, result)
      {:ok, session}
    end)

    Process.get(:__js_result__, nil)
  end
end
