defmodule ElixirDropsWeb.SponsorRedirectControllerTest do
  use ElixirDropsWeb.ConnCase, async: false

  import ElixirDrops.AccountsFixtures

  alias ElixirDrops.Repo
  alias ElixirDrops.Sponsors.SponsorEvent

  test "each route counts once and preserves the approved destination and UTMs", %{conn: conn} do
    for placement <- ~w(drop-banner drop-sidebar) do
      response = get(conn, "/go/appsignal/#{placement}")

      assert redirected_to(response, 302) ==
               "https://www.appsignal.com/?utm_source=elixirdrops&utm_medium=native&utm_campaign=appsignal_q3_2026&utm_content=#{placement}"

      assert get_resp_header(response, "cache-control") == ["private, no-store"]
    end

    assert Repo.aggregate(SponsorEvent, :count) == 2
  end

  test "HEAD, prefetch and bots redirect without counting", %{conn: conn} do
    assert head(conn, "/go/appsignal/drop-banner").status == 302

    for header <- ~w(purpose sec-purpose x-moz) do
      assert conn
             |> put_req_header(header, "prefetch")
             |> get("/go/appsignal/drop-banner")
             |> Map.fetch!(:status) == 302
    end

    assert conn
           |> put_req_header("user-agent", "Googlebot")
           |> get("/go/appsignal/drop-banner")
           |> Map.fetch!(:status) == 302

    assert Repo.aggregate(SponsorEvent, :count) == 0
  end

  test "unknown destinations cannot create redirects or counts", %{conn: conn} do
    assert get(conn, "/go/appsignal/other").status == 404
    assert Repo.aggregate(SponsorEvent, :count) == 0
  end

  test "configured signed-in QA is excluded", %{conn: conn} do
    user = user_fixture()
    old = Application.get_env(:elixir_drops, :sponsor_qa_github_usernames, [])
    Application.put_env(:elixir_drops, :sponsor_qa_github_usernames, [user.github_username])
    on_exit(fn -> Application.put_env(:elixir_drops, :sponsor_qa_github_usernames, old) end)

    signed_in = sign_in_user(conn, user)
    assert get(signed_in, "/go/appsignal/drop-banner").status == 302

    assert Repo.aggregate(SponsorEvent, :count) == 0
  end
end
