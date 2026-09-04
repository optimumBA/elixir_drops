defmodule ElixirDrops.SponsorsTest do
  use ElixirDrops.DataCase, async: false

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Sponsors
  alias ElixirDrops.Sponsors.SponsorEvent

  setup do
    old = Application.get_env(:elixir_drops, :sponsor_qa_github_usernames, [])
    Application.put_env(:elixir_drops, :sponsor_qa_github_usernames, ["sponsor-qa"])
    on_exit(fn -> Application.put_env(:elixir_drops, :sponsor_qa_github_usernames, old) end)
    :ok
  end

  test "records only unique valid placements and rejects malformed input" do
    assert {:ok, 2} =
             Sponsors.record_impressions([
               "drop-banner",
               "drop-banner",
               "drop-sidebar",
               %{},
               "other"
             ])

    assert :skipped = Sponsors.record_impressions("drop-banner")
    assert {:ok, 0} = Sponsors.record_impressions([])
    assert {:error, :unknown_placement} = Sponsors.record_click("other")
    assert :ok = Sponsors.record_click("drop-banner")
    assert Repo.aggregate(SponsorEvent, :count) == 3
  end

  test "QA and known bot requests are excluded without retaining identity" do
    for opts <- [
          [user: %User{github_username: "sponsor-qa"}],
          [user_agent: "Googlebot"],
          [user_agent: "HeadlessChrome"]
        ] do
      assert :skipped = Sponsors.record_impressions(["drop-banner"], opts)
      assert :skipped = Sponsors.record_click("drop-banner", opts)
    end

    assert Repo.aggregate(SponsorEvent, :count) == 0
    assert {:ok, 1} = Sponsors.record_impressions(["drop-banner"], user_agent: nil)
    refute :user_agent in SponsorEvent.__schema__(:fields)
    refute :user_id in SponsorEvent.__schema__(:fields)
  end

  test "reports half-open timestamp intervals, placement totals and undefined CTR" do
    from = ~U[2026-09-07 14:00:00.000000Z]
    to = ~U[2026-10-07 14:00:00.000000Z]

    for {kind, at} <- [
          {"impression", DateTime.add(from, -1)},
          {"impression", from},
          {"impression", DateTime.add(from, 1)},
          {"click", from},
          {"click", to}
        ] do
      Repo.insert!(%SponsorEvent{
        sponsor: "appsignal",
        placement: "drop-banner",
        kind: kind,
        inserted_at: at
      })
    end

    assert Sponsors.report(from, to) == %{
             "drop-banner" => %{impressions: 2, clicks: 1, ctr: 50.0},
             "drop-sidebar" => %{impressions: 0, clicks: 0, ctr: nil}
           }

    assert_raise ArgumentError, fn -> Sponsors.report(to, from) end
  end
end
