defmodule ElixirDropsWeb.SponsorRedirectReliabilityTest do
  use ElixirDropsWeb.ConnCase, async: false
  import ExUnit.CaptureLog
  alias ElixirDrops.Repo
  alias ElixirDropsWeb.SponsorRedirectController

  test "a slow database write fails open within the short budget and attempts only once" do
    Repo.query!("""
    CREATE FUNCTION pg_temp.slow_sponsor_write() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN PERFORM pg_sleep(2); RETURN NEW; END $$
    """)

    Repo.query!(
      "CREATE TRIGGER slow_sponsor_write BEFORE INSERT ON sponsor_events FOR EACH ROW EXECUTE FUNCTION pg_temp.slow_sponsor_write()"
    )

    parent = self()
    handler = {__MODULE__, make_ref()}

    :telemetry.attach(
      handler,
      [:elixir_drops, :sponsors, :event],
      fn _event, _measurements, tags, owner -> send(owner, {:outcome, tags.outcome}) end,
      parent
    )

    on_exit(fn -> :telemetry.detach(handler) end)
    started = System.monotonic_time(:millisecond)

    assert capture_log(fn ->
             conn =
               SponsorRedirectController.show(Phoenix.ConnTest.build_conn(), %{
                 "placement" => "drop-banner"
               })

             assert conn.status == 302
             assert hd(get_resp_header(conn, "location")) =~ "https://www.appsignal.com/"
           end) =~ "Failed to record sponsor event"

    assert System.monotonic_time(:millisecond) - started < 1000
    assert_receive {:outcome, "attempted"}
    assert_receive {:outcome, "failed"}
    refute_receive {:outcome, "attempted"}, 50
  end
end
