defmodule ElixirDropsWeb.Features.SponsorTrackingTest do
  use ElixirDropsWeb.FeatureCase, async: false

  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Repo
  alias ElixirDrops.Sponsors.SponsorEvent
  alias PhoenixTest.Playwright.Connection
  alias PhoenixTest.Playwright.Frame

  @moduletag :feature

  setup do
    user = user_fixture()
    %{drop: drop_fixture(%Drop{}, user)}
  end

  for {width, expected} <- [{390, 1}, {1023, 1}, {1024, 2}, {1440, 2}] do
    @width width
    @expected expected
    test "counts rendered placements at #{width}px", %{conn: conn, drop: drop} do
      session =
        conn
        |> visit("/")
        |> viewport(@width)
        |> visit("/d/#{drop.short_id}")

      assert_event_count(@expected)

      unwrap(session, fn %{frame_id: frame_id} ->
        assert @width == Frame.evaluate(frame_id, "window.innerWidth")
      end)
    end
  end

  test "patch and reconnect preserve the impression count", %{conn: conn, drop: drop} do
    session =
      conn
      |> visit("/")
      |> viewport(1440)
      |> visit("/d/#{drop.short_id}")

    assert_event_count(2)

    unwrap(session, fn %{frame_id: frame_id} ->
      assert true ==
               Frame.evaluate(
                 frame_id,
                 """
                   new Promise(resolve => {
                     window.addEventListener('phx:page-loading-stop', () => resolve(true), {once: true});
                     const link = document.createElement('a');
                     link.href = '/d/#{drop.short_id}?variant=native';
                     link.setAttribute('data-phx-link', 'patch');
                     link.setAttribute('data-phx-link-state', 'push');
                     document.body.appendChild(link);
                     link.click();
                   })
                 """,
                 timeout: 5000
               )
    end)

    patched_session = assert_has(session, "#appsignal-drop-banner[class*='bg-[#18221c]']")
    assert Repo.aggregate(SponsorEvent, :count) == 2

    unwrap(patched_session, fn %{frame_id: frame_id} ->
      assert true ==
               Frame.evaluate(
                 frame_id,
                 """
                   new Promise(resolve => {
                     window.liveSocket.disconnect(() => {
                       window.liveSocket.connect();
                       const timer = setInterval(() => {
                         if (window.liveSocket.isConnected() && document.querySelector('.phx-connected')) {
                           clearInterval(timer);
                           resolve(true);
                         }
                       }, 50);
                     });
                   })
                 """,
                 timeout: 5000
               )
    end)

    # A round trip after reattaching ensures any mounted event has been handled.
    unwrap(patched_session, fn %{frame_id: frame_id} ->
      assert true ==
               Frame.evaluate(
                 frame_id,
                 """
                   (() => {
                     const root = document.querySelector('[data-phx-main]');
                     return window.liveSocket.getViewByEl(root)
                       .pushHookEvent(root, null, 'sponsor_impression', {}).then(() => true);
                   })()
                 """,
                 timeout: 5000
               )
    end)

    assert Repo.aggregate(SponsorEvent, :count) == 2
  end

  test "widening reveals and counts the sidebar only once", %{conn: conn, drop: drop} do
    session =
      conn
      |> visit("/")
      |> viewport(390)
      |> visit("/d/#{drop.short_id}")

    assert_event_count(1)
    viewport(session, 1440)
    assert_event_count(2)

    for width <- [390, 1440, 1023, 1024] do
      viewport(session, width)

      unwrap(session, fn %{frame_id: frame_id} ->
        assert true ==
                 Frame.evaluate(
                   frame_id,
                   """
                     new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
                       .then(() => {
                         const root = document.querySelector('[data-phx-main]');
                         return window.liveSocket.getViewByEl(root).pushHookEvent(root, null, 'sponsor_impression', {});
                       }).then(() => true)
                   """,
                   timeout: 5000
                 )
      end)

      assert Repo.aggregate(SponsorEvent, :count) == 2
    end
  end

  defp viewport(session, width) do
    unwrap(session, fn %{page_id: page_id} ->
      response =
        Connection.post(
          guid: page_id,
          method: :set_viewport_size,
          params: %{viewport_size: %{width: width, height: 900}}
        )

      refute Map.has_key?(response, :error)
    end)

    session
  end

  defp assert_event_count(expected, retries \\ 60)

  defp assert_event_count(expected, 0),
    do: assert(Repo.aggregate(SponsorEvent, :count) == expected)

  defp assert_event_count(expected, retries) do
    if Repo.aggregate(SponsorEvent, :count) != expected do
      Process.sleep(50)
      assert_event_count(expected, retries - 1)
    end
  end
end
