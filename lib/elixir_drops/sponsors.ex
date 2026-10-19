defmodule ElixirDrops.Sponsors do
  @moduledoc """
  The Sponsors context.

  Tracks anonymous, aggregate-only sponsor impression and click events for
  native sponsor placements. No visitor identity, raw user agent, or IP
  address is ever stored - only the sponsor, placement, kind and timestamp.
  """

  import Ecto.Query

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Repo
  alias ElixirDrops.Sponsors.SponsorEvent
  alias ElixirDrops.Sponsors.Telemetry

  require Logger

  @type impression_status :: :persisted | :skipped | :failed
  @type kind :: String.t()
  @type opts :: keyword()
  @type placement :: String.t()

  @sponsor "appsignal"
  @placements ["drop-banner", "drop-sidebar"]
  @base_url "https://www.appsignal.com/?utm_source=elixirdrops&utm_medium=native&utm_campaign=appsignal_q3_2026"

  @query_timeout 5_000

  # Implementation budgets (not a commercial or availability SLA). An
  # impression query may take up to 1s (a replay can need a verification
  # query too); a click write gets one attempt of at
  # most 250ms and never queues for a pool connection, so a slow database
  # cannot hold up the redirect much beyond that (scheduler and network time
  # are outside this budget).
  @impression_timeout 1_000
  @click_timeout 250

  # Matches common bots, crawlers, headless browsers and link-preview /
  # prefetch tools. Intentionally conservative: a nil or unrecognized UA
  # (including LiveView's own metadata-bearing UA in tests) is treated as
  # legitimate rather than filtered, since LiveView clicks may not carry a
  # regular browser UA.
  @bot_user_agent_pattern ~r/bot|crawl|spider|headless|phantomjs|puppeteer|playwright|selenium|slurp|facebookexternalhit|slackbot|discordbot|telegrambot|whatsapp|preview|prefetch|curl|wget|python-requests|go-http-client|okhttp|bytespider|ahrefsbot|semrushbot|mj12bot|dotbot/i

  @doc """
  Lists the known sponsor placement identifiers.
  """
  @spec placements() :: [placement()]
  def placements, do: @placements

  @doc """
  Returns the fixed, approved destination URL for a placement, tagged with
  a `utm_content` equal to the placement. Returns `nil` for unknown
  placements so callers never construct or accept a user-controlled URL.
  """
  @spec destination_url(placement()) :: String.t() | nil
  def destination_url(placement) when placement in @placements do
    @base_url <> "&utm_content=#{URI.encode_www_form(placement)}"
  end

  def destination_url(_placement), do: nil

  @doc """
  Records impression events for the given placements.

  Accepts a list of placements, deduplicates them, and drops unknown or
  malformed entries. Returns `{:ok, count}` with the number of impressions
  confirmed stored, or `:skipped` when the request is attributable to QA
  or a bot/automation user agent. Resilient to a malformed whole input
  (e.g. not a list at all), returning `:skipped` in that case as well.

  ## Options

    * `:user` - the current user (used only for QA detection via GitHub
      username), if any
    * `:user_agent` - the request's user agent string, used transiently for
      bot filtering and never persisted

  """
  @spec record_impressions(list(), opts()) :: {:ok, non_neg_integer()} | :skipped
  def record_impressions(placements, opts \\ [])

  def record_impressions(placements, opts) when is_list(placements) do
    case impression_results(@sponsor, placements, opts) do
      :skipped ->
        :skipped

      {:results, results} ->
        if skip_reason(opts),
          do: :skipped,
          else: {:ok, Enum.count(results, fn {_placement, status} -> status == :persisted end)}
    end
  end

  def record_impressions(_placements, _opts), do: :skipped

  @doc """
  Generates a random event ID for `record_impression_results/2`. Callers
  (LiveViews) generate it server-side and keep it for one placement of one
  visit so a retry cannot double-count.
  """
  @spec new_event_id() :: String.t()
  def new_event_id, do: Ecto.UUID.generate()

  @doc """
  Records impressions and reports a status per valid placement:

    * `:persisted` - stored (or already stored by an earlier attempt with the
      same event ID, same sponsor, placement and kind)
    * `:skipped` - intentionally not counted (QA user or bot); final
    * `:failed` - not stored; the caller may retry with the same event ID

  Unknown or malformed placements are dropped and absent from the result.

  ## Options

  Those of `record_impressions/2`, plus `:event_ids` - a map of placement to
  server-generated UUID (see `new_event_id/0`) used as the row's primary key
  with `ON CONFLICT DO NOTHING`. Never pass client-supplied IDs.
  """
  @spec record_impression_results(list(), opts()) :: %{placement() => impression_status()}
  def record_impression_results(placements, opts \\ []) do
    case impression_results(@sponsor, placements, opts) do
      {:results, results} -> results
      :skipped -> %{}
    end
  end

  @doc "Records a separate visible-impression estimate, using server-owned event IDs."
  @spec record_visible_impression_results(list(), opts()) :: map()
  def record_visible_impression_results(placements, opts \\ []) do
    case impression_results(@sponsor, placements, opts, "visible_impression") do
      {:results, results} -> results
      :skipped -> %{}
    end
  end

  defp impression_results(sponsor, placements, opts),
    do: impression_results(sponsor, placements, opts, "impression")

  defp impression_results(sponsor, placements, opts, kind)
       when is_binary(sponsor) and is_list(placements) do
    valid = valid_impression_placements(placements, @placements)

    case skip_reason(opts) do
      nil -> {:results, persist_impressions(sponsor, valid, kind, opts)}
      reason -> skip_impressions(sponsor, valid, kind, reason)
    end
  end

  defp impression_results(_sponsor, _placements, _opts, _kind), do: :skipped

  defp valid_impression_placements(placements, allowed) do
    placements
    |> Enum.filter(&(is_binary(&1) and &1 in allowed))
    |> Enum.uniq()
  end

  defp persist_impressions(sponsor, valid, kind, opts) do
    supplied_ids = Keyword.get(opts, :event_ids, %{})
    event_ids = if is_map(supplied_ids), do: supplied_ids, else: %{}

    Map.new(valid, fn placement ->
      id = Map.get(event_ids, placement) || new_event_id()
      {placement, persist(sponsor, placement, kind, id, timeout: @impression_timeout)}
    end)
  end

  defp skip_impressions(_sponsor, [], _kind, _reason), do: :skipped

  defp skip_impressions(sponsor, valid, kind, reason) do
    results =
      Map.new(valid, fn placement ->
        metadata = meta(sponsor, placement, kind, reason)
        Telemetry.event(:skipped, metadata)
        {placement, :skipped}
      end)

    {:results, results}
  end

  @doc """
  Records a click event for the given placement.

  Returns `:ok` on success, `:skipped` when the request is attributable to
  QA or a bot/automation user agent, `{:error, :unknown_placement}` for a
  placement outside `placements/0`, or `{:error, reason}` on database
  failure.

  ## Options

    * `:user` - the current user (used only for QA detection via GitHub
      username), if any
    * `:user_agent` - the request's user agent string, used transiently for
      bot filtering and never persisted

  """
  @spec record_click(placement(), opts()) ::
          :ok | :skipped | {:error, :unknown_placement} | {:error, any()}
  def record_click(placement, opts \\ []) do
    if is_binary(placement) and placement in @placements do
      do_record_click(@sponsor, placement, opts)
    else
      {:error, :unknown_placement}
    end
  end

  # One write attempt, bounded by @click_timeout and no pool queueing; there
  # is no retry because a retry would delay the redirect further.
  defp do_record_click(sponsor, placement, opts) do
    case skip_reason(opts) do
      nil ->
        case persist(sponsor, placement, "click", new_event_id(),
               timeout: @click_timeout,
               queue: false
             ) do
          :persisted -> :ok
          :failed -> {:error, :write_failed}
        end

      reason ->
        Telemetry.event(:skipped, meta(sponsor, placement, "click", reason))
        :skipped
    end
  end

  @doc """
  Builds an impressions/clicks/CTR report for every known placement over a
  half-open `[from, to)` UTC datetime range.

  `ctr` is expressed as a percentage, rounded to two decimal
  places, and is `nil` when there were zero impressions for that
  placement (avoiding a misleading `0.0%`).

  Always returns an entry for every placement in `placements/0`, even when
  it has no events in the range.

  Raises `ArgumentError` if `from` is not strictly before `to`.
  """
  @spec report(DateTime.t(), DateTime.t()) :: %{
          placement() => %{
            impressions: non_neg_integer(),
            clicks: non_neg_integer(),
            ctr: float() | nil
          }
        }
  def report(%DateTime{} = from, %DateTime{} = to) do
    if DateTime.compare(from, to) != :lt do
      raise ArgumentError, "from must be strictly before to"
    end

    counts = event_counts(@sponsor, from, to)

    Map.new(@placements, fn placement ->
      placement_counts = Map.get(counts, placement, %{})
      impressions = Map.get(placement_counts, "impression", 0)
      clicks = Map.get(placement_counts, "click", 0)

      {placement, %{impressions: impressions, clicks: clicks, ctr: ctr(clicks, impressions)}}
    end)
  end

  @doc """
  Separate visible-impression estimates per placement for a half-open interval.
  Historical `report` maps and their served-impression CTR remain unchanged.
  Before deployment of visibility tracking, these counts are unavailable rather
  than evidence of zero exposure; use only intervals with recorded coverage.
  """
  @spec visibility_report(DateTime.t(), DateTime.t()) :: map()
  def visibility_report(%DateTime{} = from, %DateTime{} = to) do
    if DateTime.compare(from, to) != :lt,
      do: raise(ArgumentError, "from must be strictly before to")

    counts = event_counts(@sponsor, from, to)

    Map.new(@placements, fn placement ->
      {placement, %{visible_impressions: get_in(counts, [placement, "visible_impression"]) || 0}}
    end)
  end

  defp event_counts(sponsor, from, to) do
    SponsorEvent
    |> where([e], e.sponsor == ^sponsor and e.inserted_at >= ^from and e.inserted_at < ^to)
    |> group_by([e], [e.placement, e.kind])
    |> select([e], {e.placement, e.kind, count(e.id)})
    |> Repo.all(timeout: @query_timeout)
    |> Enum.reduce(%{}, fn {placement, kind, count}, acc ->
      Map.update(acc, placement, %{kind => count}, &Map.put(&1, kind, count))
    end)
  end

  defp ctr(_clicks, 0), do: nil
  defp ctr(clicks, impressions), do: Float.round(clicks / impressions * 100, 2)

  defp skip_reason(opts) do
    cond do
      qa_user?(Keyword.get(opts, :user)) -> :qa
      bot_user_agent?(Keyword.get(opts, :user_agent)) -> :bot
      true -> nil
    end
  end

  defp qa_user?(%User{github_username: github_username}) when is_binary(github_username) do
    github_username in qa_github_usernames()
  end

  defp qa_user?(_user), do: false

  defp qa_github_usernames do
    :elixir_drops
    |> Application.get_env(:sponsor_qa_github_usernames, [])
    |> List.wrap()
  end

  defp bot_user_agent?(user_agent) when is_binary(user_agent) do
    Regex.match?(@bot_user_agent_pattern, user_agent)
  end

  defp bot_user_agent?(_user_agent), do: false

  defp meta(sponsor, placement, kind, reason \\ nil),
    do: %{sponsor: sponsor, placement: placement, kind: kind, reason: reason}

  # Single insert attempt with telemetry and failure logging. Logs carry only
  # sponsor, placement, kind and a failure class; never IDs, UAs or IPs.
  defp persist(sponsor, placement, kind, id, db_opts) do
    meta = meta(sponsor, placement, kind)
    started = System.monotonic_time()
    Telemetry.event(:attempted, meta)

    {outcome, reason} =
      case insert_event(sponsor, placement, kind, id, db_opts) do
        :ok -> {:persisted, nil}
        {:error, reason} -> {:failed, reason}
      end

    started
    |> Telemetry.elapsed_ms()
    |> Telemetry.write_duration(Map.put(meta, :outcome, outcome))

    Telemetry.event(outcome, meta)

    if outcome == :failed do
      Logger.error(
        "Failed to record sponsor event sponsor=#{sponsor} placement=#{placement} " <>
          "kind=#{kind} reason=#{reason}"
      )
    end

    outcome
  end

  defp insert_event(sponsor, placement, kind, id, db_opts) do
    attrs = %{sponsor: sponsor, placement: placement, kind: kind}
    changeset = SponsorEvent.changeset(%SponsorEvent{}, attrs)

    if changeset.valid? do
      row = Map.merge(attrs, %{id: id, inserted_at: DateTime.utc_now()})

      case Repo.insert_all(
             SponsorEvent,
             [row],
             [on_conflict: :nothing, conflict_target: :id] ++ db_opts
           ) do
        {1, _} -> :ok
        {0, _} -> verify_existing(attrs, id, db_opts)
      end
    else
      {:error, :invalid_event}
    end
  rescue
    error -> {:error, error.__struct__}
  catch
    :exit, _exit_reason -> {:error, :exit}
  end

  # A conflict is only a harmless replay when the stored row is the very same
  # sponsor, placement and kind; anything else must not be acknowledged.
  defp verify_existing(attrs, id, db_opts) do
    matches? =
      SponsorEvent
      |> where(
        [e],
        e.id == ^id and e.sponsor == ^attrs.sponsor and e.placement == ^attrs.placement and
          e.kind == ^attrs.kind
      )
      |> Repo.exists?(db_opts)

    if matches?, do: :ok, else: {:error, :event_id_mismatch}
  end
end
