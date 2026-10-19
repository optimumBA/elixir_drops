defmodule ElixirDrops.SponsorReliabilityTest do
  use ElixirDrops.DataCase, async: false

  import ExUnit.CaptureLog
  alias ElixirDrops.Sponsors
  alias ElixirDrops.Sponsors.SponsorEvent
  alias ElixirDrops.Sponsors.Telemetry
  alias ElixirDropsWeb.DropLive.Show
  alias Phoenix.LiveView.Socket

  setup do
    owner = self()
    id = {__MODULE__, make_ref()}

    :telemetry.attach_many(
      id,
      [[:elixir_drops, :sponsors, :event], [:elixir_drops, :sponsors, :write]],
      fn event, measurements, tags, pid ->
        send(pid, {:sponsor_metric, event, measurements, tags})
      end,
      owner
    )

    on_exit(fn -> :telemetry.detach(id) end)
    :ok
  end

  defp reject_sidebar do
    Repo.query!("""
    CREATE FUNCTION pg_temp.reject_sponsor_sidebar() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      IF NEW.placement = 'drop-sidebar' AND current_setting('elixir_drops.fail_sidebar', true) = 'on' THEN
        RETURN NULL;
      END IF;
      RETURN NEW;
    END $$
    """)

    Repo.query!(
      "CREATE TRIGGER reject_sponsor_sidebar BEFORE INSERT ON sponsor_events FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_sponsor_sidebar()"
    )

    Repo.query!("SET LOCAL elixir_drops.fail_sidebar = 'on'")
  end

  test "partial persistence failure is not acknowledged and retry stores only missing placement" do
    reject_sidebar()
    drop = %{id: Ecto.UUID.generate(), short_id: "testdrop"}
    socket = %Socket{assigns: %{__changed__: %{}, drop: drop, current_user: nil}}
    payload = %{"drop_id" => "testdrop", "placements" => ["drop-banner", "drop-sidebar"]}

    {{reply, failed_socket}, log} =
      with_log(fn ->
        {:reply, acknowledgment, updated_socket} =
          Show.handle_event("sponsor_impression", payload, socket)

        {acknowledgment, updated_socket}
      end)

    assert log =~ "Failed to record sponsor event"

    assert reply == %{acknowledged: ["drop-banner"]}
    assert Repo.aggregate(SponsorEvent, :count) == 1

    assert_receive {:sponsor_metric, _event, %{count: 1},
                    %{outcome: "failed", placement: "drop-sidebar"}}

    Repo.query!("SET LOCAL elixir_drops.fail_sidebar = 'off'")

    assert {:reply, %{acknowledged: placements}, successful_socket} =
             Show.handle_event("sponsor_impression", payload, failed_socket)

    assert Enum.sort(placements) == ["drop-banner", "drop-sidebar"]

    assert {:reply, %{acknowledged: _acknowledgment}, _unchanged_socket} =
             Show.handle_event("sponsor_impression", payload, successful_socket)

    assert Repo.aggregate(SponsorEvent, :count) == 2
  end

  test "a lost acknowledgment replay is idempotent and an ID from another origin is rejected" do
    id = Sponsors.new_event_id()
    opts = [event_ids: %{"drop-banner" => id}]

    assert %{"drop-banner" => :persisted} =
             Sponsors.record_impression_results(["drop-banner"], opts)

    assert %{"drop-banner" => :persisted} =
             Sponsors.record_impression_results(["drop-banner"], opts)

    assert Repo.aggregate(SponsorEvent, :count) == 1

    assert capture_log(fn ->
             assert %{"drop-sidebar" => :failed} =
                      Sponsors.record_impression_results(["drop-sidebar"],
                        event_ids: %{"drop-sidebar" => id}
                      )
           end) =~ "event_id_mismatch"

    assert Repo.aggregate(SponsorEvent, :count) == 1
  end

  test "intentional exclusion is final and visible estimates remain separate from historical report shape" do
    assert %{"drop-banner" => :skipped} =
             Sponsors.record_visible_impression_results(["drop-banner"],
               user_agent: "Googlebot"
             )

    assert_receive {:sponsor_metric, _event, %{count: 1}, %{outcome: "skipped", reason: "bot"}}
    assert :skipped = Sponsors.record_impressions(["drop-banner"], user_agent: "Googlebot")
    assert %{} = Sponsors.record_impression_results([%{}, "bad"])
    assert %{} = Sponsors.record_visible_impression_results(nil, [])

    assert %{"drop-banner" => :persisted} =
             Sponsors.record_visible_impression_results(["drop-banner"], [])

    from = DateTime.add(DateTime.utc_now(), -60)
    to = DateTime.add(DateTime.utc_now(), 60)

    assert Sponsors.report(from, to) == %{
             "drop-banner" => %{impressions: 0, clicks: 0, ctr: nil},
             "drop-sidebar" => %{impressions: 0, clicks: 0, ctr: nil}
           }

    assert Sponsors.visibility_report(from, to) == %{
             "drop-banner" => %{visible_impressions: 1},
             "drop-sidebar" => %{visible_impressions: 0}
           }
  end

  test "metrics actually call the existing AppSignal backend with bounded anonymous tags" do
    Code.ensure_loaded!(Appsignal)
    parent = self()

    loop = fn loop ->
      receive do
        {:trace, _caller, :call, {Appsignal, fun, args}} ->
          send(parent, {:backend, fun, args})
          loop.(loop)

        :stop ->
          :ok
      end
    end

    tracer = spawn(fn -> loop.(loop) end)
    :erlang.trace_pattern({Appsignal, :increment_counter, 3}, true, [])
    :erlang.trace_pattern({Appsignal, :add_distribution_value, 3}, true, [])
    :erlang.trace(self(), true, [:call, {:tracer, tracer}])

    on_exit(fn ->
      :erlang.trace_pattern({Appsignal, :increment_counter, 3}, false, [])
      :erlang.trace_pattern({Appsignal, :add_distribution_value, 3}, false, [])
      send(tracer, :stop)
    end)

    Telemetry.event(:persisted, %{
      sponsor: "appsignal",
      placement: "drop-banner",
      kind: "impression",
      user_agent: "private",
      id: "secret"
    })

    Telemetry.redirect_duration(12, %{
      sponsor: "appsignal",
      placement: "drop-sidebar",
      outcome: :persisted
    })

    assert_receive {:backend, :increment_counter, ["sponsor_event", 1, tags]}

    assert tags == %{
             sponsor: "appsignal",
             placement: "drop-banner",
             kind: "impression",
             outcome: "persisted"
           }

    assert_receive {:backend, :add_distribution_value,
                    [
                      "sponsor_redirect_ms",
                      12,
                      %{sponsor: "appsignal", placement: "drop-sidebar", outcome: "persisted"}
                    ]}
  end
end
