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

  require Logger

  @type kind :: String.t()
  @type opts :: keyword()
  @type placement :: String.t()

  @sponsor "appsignal"
  @placements ["drop-banner", "drop-sidebar"]
  @base_url "https://www.appsignal.com/?utm_source=elixirdrops&utm_medium=native&utm_campaign=appsignal_q3_2026"
  @query_timeout 5_000

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
  actually recorded, or `:skipped` when the request is attributable to QA
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
    if skip_event?(opts) do
      :skipped
    else
      valid_placements =
        placements
        |> Enum.filter(&(is_binary(&1) and &1 in @placements))
        |> Enum.uniq()

      count = insert_events(valid_placements, "impression")
      {:ok, count}
    end
  end

  def record_impressions(_placements, _opts), do: :skipped

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
  def record_click(placement, opts \\ [])

  def record_click(placement, opts) when placement in @placements do
    if skip_event?(opts) do
      :skipped
    else
      case insert_event(placement, "click") do
        {:ok, _event} ->
          :ok

        {:error, reason} ->
          Logger.error("Failed to record sponsor click for placement #{placement}")
          {:error, reason}
      end
    end
  end

  def record_click(_placement, _opts), do: {:error, :unknown_placement}

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

    counts = event_counts(from, to)

    Map.new(@placements, fn placement ->
      placement_counts = Map.get(counts, placement, %{})
      impressions = Map.get(placement_counts, "impression", 0)
      clicks = Map.get(placement_counts, "click", 0)

      {placement, %{impressions: impressions, clicks: clicks, ctr: ctr(clicks, impressions)}}
    end)
  end

  defp event_counts(from, to) do
    SponsorEvent
    |> where([e], e.sponsor == ^@sponsor and e.inserted_at >= ^from and e.inserted_at < ^to)
    |> group_by([e], [e.placement, e.kind])
    |> select([e], {e.placement, e.kind, count(e.id)})
    |> Repo.all(timeout: @query_timeout)
    |> Enum.reduce(%{}, fn {placement, kind, count}, acc ->
      Map.update(acc, placement, %{kind => count}, &Map.put(&1, kind, count))
    end)
  end

  defp ctr(_clicks, 0), do: nil
  defp ctr(clicks, impressions), do: Float.round(clicks / impressions * 100, 2)

  defp skip_event?(opts) do
    qa_user?(Keyword.get(opts, :user)) || bot_user_agent?(Keyword.get(opts, :user_agent))
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

  defp insert_events(placements, kind) do
    Enum.reduce(placements, 0, fn placement, count ->
      case insert_event(placement, kind) do
        {:ok, _event} -> count + 1
        {:error, _changeset} -> count
      end
    end)
  end

  defp insert_event(placement, kind) do
    %SponsorEvent{}
    |> SponsorEvent.changeset(%{sponsor: @sponsor, placement: placement, kind: kind})
    |> Repo.insert(timeout: @query_timeout)
  rescue
    error ->
      Logger.error("Failed to persist sponsor event (kind=#{kind})")
      {:error, error}
  end
end
