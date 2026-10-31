defmodule ElixirDrops.Sponsors.Telemetry do
  @moduledoc """
  Bounded, low-cardinality observability for sponsor event writes and redirects.

  Every call emits a `:telemetry` event and forwards the same measurement to
  AppSignal custom metrics (`Appsignal.increment_counter/3` and
  `Appsignal.add_distribution_value/3`). Tags are limited to sponsor,
  placement, kind, outcome and (for skips) reason; never user agents, IPs,
  users or event IDs.

  Metric emission is best effort and never raises into the request. These
  metrics are an operational signal, not a retained count or availability
  history; retention is owned by the AppSignal account.

  ## Telemetry events

    * `[:elixir_drops, :sponsors, :event]` - measurements `%{count: 1}`
    * `[:elixir_drops, :sponsors, :write]` - measurements `%{duration_ms: n}`
    * `[:elixir_drops, :sponsors, :redirect]` - measurements `%{duration_ms: n}`

  ## AppSignal metrics

    * `sponsor_event` counter, tags `sponsor, placement, kind, outcome[, reason]`
    * `sponsor_event_write_ms` distribution, tags `sponsor, placement, kind, outcome`
    * `sponsor_redirect_ms` distribution, tags `sponsor, placement, outcome`
  """

  require Logger

  @backend Application.compile_env(:elixir_drops, :sponsor_metrics_backend, Appsignal)

  @type metadata :: map()
  @type native_time :: integer()
  @type outcome :: :attempted | :persisted | :skipped | :failed

  @doc "Counts one event outcome (`:attempted`, `:persisted`, `:skipped`, `:failed`)."
  @spec event(outcome(), metadata()) :: :ok
  def event(outcome, meta) when outcome in [:attempted, :persisted, :skipped, :failed] do
    tags = tags(Map.put(meta, :outcome, outcome))
    safely(fn -> :telemetry.execute([:elixir_drops, :sponsors, :event], %{count: 1}, tags) end)
    safely(fn -> @backend.increment_counter("sponsor_event", 1, tags) end)
  end

  @doc "Records the duration of one event write, in milliseconds."
  @spec write_duration(non_neg_integer(), metadata()) :: :ok
  def write_duration(duration_ms, meta),
    do: duration(:write, "sponsor_event_write_ms", duration_ms, meta)

  @doc "Records the duration of one sponsor redirect (including its click write)."
  @spec redirect_duration(non_neg_integer(), metadata()) :: :ok
  def redirect_duration(duration_ms, meta),
    do: duration(:redirect, "sponsor_redirect_ms", duration_ms, Map.delete(meta, :kind))

  @doc "Elapsed milliseconds since a `System.monotonic_time/0` start."
  @spec elapsed_ms(native_time()) :: non_neg_integer()
  def elapsed_ms(started),
    do: System.convert_time_unit(System.monotonic_time() - started, :native, :millisecond)

  defp duration(name, key, duration_ms, meta) do
    tags = tags(meta)

    safely(fn ->
      :telemetry.execute([:elixir_drops, :sponsors, name], %{duration_ms: duration_ms}, tags)
    end)

    safely(fn -> @backend.add_distribution_value(key, duration_ms, tags) end)
  end

  defp tags(meta) do
    for {key, value} <- meta,
        key in [:sponsor, :placement, :kind, :outcome, :reason],
        not is_nil(value),
        into: %{},
        do: {key, to_string(value)}
  end

  defp safely(fun) do
    fun.()
    :ok
  rescue
    _exception -> Logger.warning("Sponsor metric emission failed")
  catch
    _failure_kind, _failure_reason -> Logger.warning("Sponsor metric emission failed")
  end
end
