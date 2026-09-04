defmodule ElixirDropsWeb.SponsorImpressionTest do
  use ElixirDropsWeb.ConnCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Repo
  alias ElixirDrops.Sponsors.SponsorEvent

  setup do
    user = user_fixture()
    %{user: user, drop: drop_fixture(%Drop{}, user)}
  end

  test "both placements count once, same-drop patches and repeats do not recount", %{
    conn: conn,
    drop: drop
  } do
    {:ok, view, _html} = live(conn, "/d/#{drop.short_id}")
    assert has_element?(view, "[phx-hook='SponsorImpression'][data-drop-id='#{drop.short_id}']")

    payload = %{
      "drop_id" => drop.short_id,
      "placements" => ["drop-banner", "drop-sidebar", "drop-banner"]
    }

    render_hook(view, "sponsor_impression", payload)
    assert Repo.aggregate(SponsorEvent, :count) == 2
    render_patch(view, "/d/#{drop.short_id}?variant=native")
    render_hook(view, "sponsor_impression", payload)
    assert Repo.aggregate(SponsorEvent, :count) == 2
  end

  test "malformed or stale events do not poison a later banner-only impression", %{
    conn: conn,
    drop: drop
  } do
    {:ok, view, _html} = live(conn, "/d/#{drop.short_id}")

    for payload <- [
          %{},
          %{"drop_id" => "other", "placements" => ["drop-banner"]},
          %{"drop_id" => drop.short_id, "placements" => "drop-banner"},
          %{"drop_id" => drop.short_id, "placements" => [%{}, "unknown"]}
        ] do
      render_hook(view, "sponsor_impression", payload)
    end

    assert Repo.aggregate(SponsorEvent, :count) == 0

    render_hook(view, "sponsor_impression", %{
      "drop_id" => drop.short_id,
      "placements" => ["drop-banner"]
    })

    assert [%{placement: "drop-banner"}] = Repo.all(SponsorEvent)
  end

  test "sidebar revealed later counts once without recounting the banner", %{
    conn: conn,
    drop: drop
  } do
    {:ok, view, _html} = live(conn, "/d/#{drop.short_id}")

    render_hook(view, "sponsor_impression", %{
      "drop_id" => drop.short_id,
      "placements" => ["drop-banner"]
    })

    assert Repo.aggregate(SponsorEvent, :count) == 1

    for placements <- [["drop-sidebar"], ["drop-banner", "drop-sidebar"], ["drop-sidebar"]] do
      render_hook(view, "sponsor_impression", %{
        "drop_id" => drop.short_id,
        "placements" => placements
      })

      assert Repo.aggregate(SponsorEvent, :count) == 2
    end
  end

  test "QA user impressions are excluded", %{conn: conn, user: user, drop: drop} do
    old = Application.get_env(:elixir_drops, :sponsor_qa_github_usernames, [])
    Application.put_env(:elixir_drops, :sponsor_qa_github_usernames, [user.github_username])
    on_exit(fn -> Application.put_env(:elixir_drops, :sponsor_qa_github_usernames, old) end)
    signed_in = sign_in_user(conn, user)
    {:ok, view, _html} = live(signed_in, "/d/#{drop.short_id}")

    render_hook(view, "sponsor_impression", %{
      "drop_id" => drop.short_id,
      "placements" => ["drop-banner"]
    })

    assert Repo.aggregate(SponsorEvent, :count) == 0
  end
end
