defmodule ElixirDropsWeb.ArchiveControllerTest do
  use ElixirDropsWeb.ConnCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Repo

  test "lists every drop newest first with dates and available authors", %{conn: conn} do
    user = user_fixture()

    original_older_drop =
      drop_fixture(%Drop{}, user, %{
        body: "ARCHIVE_PRIVATE_BODY_MARKER",
        screenshot: %{
          internal_url: "https://images.example/internal-only.png",
          meta_url: "https://images.example/meta-only.png",
          status: :completed
        },
        title: "Older archive title"
      })

    original_newer_drop =
      drop_fixture(%Drop{}, user, %{
        body: "ARCHIVE_PRIVATE_BODY_MARKER",
        title: "Newer archive title"
      })

    additional_drops =
      for number <- 1..15 do
        drop_fixture(%Drop{}, user, %{
          body: "ARCHIVE_PRIVATE_BODY_MARKER",
          title: "Archive item #{number}"
        })
      end

    older_drop =
      original_older_drop
      |> Ecto.Changeset.change(inserted_at: ~N[2026-08-15 12:00:00])
      |> Repo.update!()

    newer_drop =
      original_newer_drop
      |> Ecto.Changeset.change(inserted_at: ~N[2026-09-15 12:00:00])
      |> Repo.update!()

    conn = get(conn, "/archive")
    html = response(conn, 200)
    markdown_conn = get(build_conn(), "/index.md")
    markdown = response(markdown_conn, 200)
    titles = [older_drop.title, newer_drop.title | Enum.map(additional_drops, & &1.title)]

    assert html =~ "All drops"
    assert html =~ "September 2026"
    assert html =~ "August 2026"
    assert html =~ "href=\"/d/#{newer_drop.short_id}\""
    assert html =~ "href=\"/d/#{older_drop.short_id}\""
    assert html =~ user.github_username
    assert html =~ "<time datetime=\"#{NaiveDateTime.to_iso8601(newer_drop.inserted_at)}\">"

    assert html =~
             "<link rel=\"canonical\" href=\"#{ElixirDropsWeb.Endpoint.url()}/archive\">"

    assert html =~
             ~s(<meta name="description" content="Browse every Elixir, Phoenix, and OTP tip published on ElixirDrops.">)

    assert {newer_position, _newer_length} = :binary.match(html, newer_drop.title)
    assert {older_position, _older_length} = :binary.match(html, older_drop.title)
    assert newer_position < older_position

    for title <- titles do
      assert html =~ title
      assert markdown =~ title
    end

    assert [markdown_canonical] = get_resp_header(markdown_conn, "link")
    assert markdown_canonical =~ "/archive"
    assert markdown_canonical =~ ~s(rel="canonical")

    refute html =~ "ARCHIVE_PRIVATE_BODY_MARKER"
    refute html =~ "internal-only.png"
    refute html =~ "meta-only.png"
  end
end
