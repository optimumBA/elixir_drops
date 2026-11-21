defmodule ElixirDropsWeb.ProfileLive.ShowTest do
  @moduledoc """
  The public profile Comments activity feed through the real LiveView: batches,
  states, tab-switch retention and restoration of previously loaded entries.
  """
  # The retry test renames the comments table to force a failed batch; the DDL
  # runs inside the test's sandbox transaction, so the suite stays serial.
  use ElixirDropsWeb.ConnCase, async: false

  import Ecto.Query
  import ElixirDrops.AccountsFixtures
  import ElixirDrops.CommentsFixtures
  import ElixirDrops.DropsFixtures
  import Phoenix.LiveViewTest

  alias ElixirDrops.Comments.Comment
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Repo

  defp activity(author, rival, count) do
    drop = drop_fixture(%Drop{}, rival, %{title: "Activity Drop"})
    start = base()

    for i <- 1..count do
      {parent, body} =
        if rem(i, 3) == 0 do
          parent = comment_fixture(drop, rival, nil, %{body: "PAR-#{i} parent"})
          {parent, "RPL-#{i} reply"}
        else
          {nil, "CMT-#{i} comment"}
        end

      comment = comment_fixture(drop, author, parent, %{body: body})
      ts = NaiveDateTime.add(start, -div(i - 1, 4) * 60)
      query = from(c in Comment, where: c.id == ^comment.id)
      Repo.update_all(query, set: [inserted_at: ts])
      %{comment | inserted_at: ts}
    end
  end

  defp base do
    now = NaiveDateTime.utc_now()
    NaiveDateTime.truncate(now, :second)
  end

  defp tokens(html) do
    text =
      html
      |> container()
      |> Floki.text(sep: " ")

    ~r/\b(?:CMT|RPL)-\d+\b/
    |> Regex.scan(text)
    |> List.flatten()
  end

  defp container(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("#profile-comments")
  end

  defp entry_ids(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("#profile-comments [data-feed-entry]")
    |> Enum.map(&Floki.attribute(&1, "id"))
    |> List.flatten()
  end

  defp feed_state(html) do
    node =
      html
      |> Floki.parse_document!()
      |> Floki.find("#profile-comments [data-feed-state]")
      |> List.first()

    node
    |> Floki.attribute("data-feed-state")
    |> List.first()
  end

  defp body_tokens(entries) do
    Enum.map(entries, fn entry ->
      entry.body
      |> String.split()
      |> List.first()
    end)
  end

  defp load_more(view) do
    render_hook(view, "load_more", %{})
    render_async(view, 10_000)
  end

  setup do
    author = user_fixture(%{name: "Feed Author"})
    rival = user_fixture(%{name: "Feed Rival"})
    %{author: author, rival: rival, path: ~p"/u/#{author.id}/comments"}
  end

  test "guests and signed-in visitors see the same newest-first first batch", %{
    conn: conn,
    author: author,
    rival: rival,
    path: path
  } do
    activity(author, rival, 15)
    {:ok, guest_view, _html} = live(conn, path)
    guest_html = render_async(guest_view, 10_000)
    guest = tokens(guest_html)
    assert length(guest) == 10

    {:ok, member_view, _html} = live(sign_in_user(conn, rival), path)
    html = render_async(member_view, 10_000)
    assert tokens(html) == guest
    assert feed_state(html) == "idle"
    refute html =~ "not available yet"
    assert html =~ "15 Comments"
  end

  test "a contributor without comments gets the empty state", %{conn: conn, path: path} do
    {:ok, view, _html} = live(conn, path)
    html = render_async(view, 10_000)
    assert feed_state(html) == "empty"
    assert html =~ "No comments to show yet."
    assert tokens(html) == []
  end

  test "continuation batches append ten at a time until exhausted", %{
    conn: conn,
    author: author,
    rival: rival,
    path: path
  } do
    entries = activity(author, rival, 25)
    {:ok, view, _html} = live(conn, path)
    first_html = render_async(view, 10_000)
    first = tokens(first_html)
    assert length(first) == 10

    second_html = load_more(view)
    second = tokens(second_html)
    assert length(second) == 20
    assert Enum.take(second, 10) == first

    third_html = load_more(view)
    third = tokens(third_html)
    assert length(third) == 25
    assert Enum.take(third, 20) == second
    assert feed_state(third_html) == "exhausted"
    expected = body_tokens(entries)
    assert Enum.sort(third) == Enum.sort(expected)
  end

  test "a failed batch keeps loaded entries, offers retry and re-requests the same batch", %{
    conn: conn,
    author: author,
    rival: rival,
    path: path
  } do
    activity(author, rival, 25)
    {:ok, view, _html} = live(conn, path)
    first_html = render_async(view, 10_000)
    first = tokens(first_html)

    Repo.query!("ALTER TABLE comments RENAME TO comments_failed_by_test")
    failed = load_more(view)
    Repo.query!("ALTER TABLE comments_failed_by_test RENAME TO comments")

    assert feed_state(failed) == "retry"
    assert tokens(failed) == first
    assert has_element?(view, "#profile-comments-retry button")

    view
    |> element("#profile-comments-retry button")
    |> render_click()

    done_html = render_async(view, 10_000)
    done = tokens(done_html)
    assert length(done) == 20
    assert Enum.take(done, 10) == first
  end

  test "switching to Drops and back keeps the loaded comments entries", %{
    conn: conn,
    author: author,
    rival: rival,
    path: path
  } do
    activity(author, rival, 25)
    drop_fixture(%Drop{}, author, %{title: "Author Drop"})
    {:ok, view, _html} = live(conn, path)
    loaded_html = load_more(view)
    loaded = tokens(loaded_html)
    assert length(loaded) == 20

    forth =
      view
      |> element("#profile-drops-tab")
      |> render_click()

    assert forth =~ "Author Drop"

    again =
      view
      |> element("#profile-comments-tab")
      |> render_click()

    assert tokens(again) == loaded
  end

  test "restore_profile_feed restores saved stream dom ids in their saved order", %{
    conn: conn,
    author: author,
    rival: rival,
    path: path
  } do
    activity(author, rival, 25)
    {:ok, view, _html} = live(conn, path)
    loaded_html = load_more(view)
    loaded = tokens(loaded_html)
    saved_ids = entry_ids(loaded_html)
    assert length(saved_ids) == 20

    # A fresh visit renders only the first batch; the hook asks for what it had.
    {:ok, fresh, _html} = live(conn, path)
    fresh_html = render_async(fresh, 10_000)
    fresh_tokens = tokens(fresh_html)
    assert length(fresh_tokens) == 10

    restored =
      render_hook(fresh, "restore_profile_feed", %{
        "tab" => "comments",
        "ids" => Enum.reverse(saved_ids),
        "anchor" => List.first(saved_ids)
      })

    assert tokens(restored) == Enum.reverse(loaded)
    assert entry_ids(restored) == Enum.reverse(saved_ids)
  end
end
