defmodule ElixirDropsWeb.Features.SponsorVisibilityTest do
  # Browser sessions observe shared sponsor events and PubSub state.
  use ElixirDropsWeb.FeatureCase, async: false

  import Ecto.Query

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

  defp count_visible do
    SponsorEvent
    |> where([event], event.kind == "visible_impression" and event.placement == "drop-banner")
    |> Repo.aggregate(:count)
  end

  defp pause(session, ms),
    do: evaluate(session, "new Promise(resolve => setTimeout(() => resolve(true), #{ms}))")

  defp evaluate(session, js) do
    Frame.evaluate(session.frame_id, js, timeout: 6000)
  end

  defp viewport(session, width, height) do
    unwrap(session, fn %{page_id: page} ->
      response =
        Connection.post(
          guid: page,
          method: :set_viewport_size,
          params: %{viewport_size: %{width: width, height: height}}
        )

      refute Map.has_key?(response, :error)
    end)

    session
  end

  test "below-fold banner qualifies after scrolling and a continuous second; resize and reconnect do not duplicate",
       %{conn: conn, drop: drop} do
    session =
      conn
      |> visit("/")
      |> viewport(1280, 200)
      |> visit("/d/#{drop.short_id}")

    pause(session, 1200)
    assert count_visible() == 0

    evaluate(
      session,
      "document.querySelector('#appsignal-drop-banner').scrollIntoView({block: 'center'}); true"
    )

    pause(session, 500)
    assert count_visible() == 0
    pause(session, 800)
    assert count_visible() == 1
    viewport(session, 390, 800)
    viewport(session, 1280, 900)

    evaluate(
      session,
      "new Promise(resolve => window.liveSocket.disconnect(() => { window.liveSocket.connect(); setTimeout(() => resolve(true), 700) }))"
    )

    pause(session, 1200)
    assert count_visible() == 1
  end
end
