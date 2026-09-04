# Sponsor tracking and reporting

[Start here](../README.md)

The app owns AppSignal measurement. Campaign terms, approved creative and actual
flight dates remain in the linked [campaign record](</Users/almirsarajcic/Library/Mobile Documents/com~apple~CloudDocs/Projects/ElixirDrops - What's next/artifacts/operations/sponsor-campaigns/appsignal-detail-page-2026.md>).

## What is counted

- Served-impression estimate: a browser connects to a Drop's LiveView and its
  sponsor unit has a rendered size. Banner and sidebar are counted separately;
  the sidebar follows the actual responsive CSS. This does not measure whether
  the visitor saw the unit, scrolled to it, or spent time viewing it.
- The hook checks on mount and observes placement size changes. Each placement
  counts once per Drop visit: widening a small window adds the sidebar when it
  first renders; repeated narrow/wide toggles do not recount it. Client and
  LiveView deduplication also suppress repeats from same-Drop patches and
  ordinary reconnects. Reloading or a replacement process can count a new visit.
- Click: a request to `/go/appsignal/drop-banner` or
  `/go/appsignal/drop-sidebar`. HEAD, prefetch and known bot requests are
  excluded. Destinations and agency UTMs are fixed in `ElixirDrops.Sponsors`.
- Configured, signed-in QA accounts are excluded from both metrics. GitHub
  usernames and user agents are checked transiently; the table retains only
  sponsor, placement, event kind, timestamp and a random event ID.
- CTR is clicks / impressions × 100, rounded to two decimals; `nil` means no
  impressions. Clicks can occur before LiveView connects or without JavaScript,
  so CTR is an estimate and may exceed 100%. Bot filtering is heuristic.

Plausible stays unchanged as an optional traffic cross-check. Its device buckets
and script-blocking behavior do not define the sponsor counts. No sponsor goals,
tracking pixel, new service, campaign database or admin UI is needed. The one
`sponsor_events` table uses the app's existing Postgres database.

The sponsor-color treatment is permanent; the old `?variant=native` comparison
no longer changes the ads. This was selected by Almir on 2026-09-07.

Event inserts run synchronously on the server, not in a job queue. Impressions
arrive after rendering via LiveView; redirects insert the click before returning 302. Each is a small database write, but database slowness can delay a response.
The write timeout is five seconds; persistence errors are logged and fail open.

## Before deployment

Inputs: approved creative, actual flight start/end, deployment access, and the
GitHub usernames used for QA. Start in the source repository root. Almir owns
launch, reports and removal; this document does not authorize deployment.

1. Set `SPONSOR_QA_GITHUB_USERNAMES` to a comma-separated list of the actual QA
   account usernames in the deployment environment. The default excludes no
   accounts. Stay signed in for production QA; do logged-out checks locally.
2. Run the migration with the normal release migration procedure before serving
   this version. Use `mix ecto.migrate` locally; the release already exposes
   `ElixirDrops.Release.migrate/0` for deployment migration commands.
3. Run `make ci`, then the focused browser check:
   `FEATURE_TESTS=true PW_TIMEOUT=5000 mix test --include feature test/elixir_drops_web/features/sponsor_tracking_test.exs`.
   These tests use the test database, not production.
4. Verify the runtime exclusion list through the release console and confirm
   existing database backups cover `sponsor_events`.
5. At authorized launch, verify both redirects and mobile/desktop placements on
   the live site. Confirm excluded QA does not increase counts. Capture the exact
   actual start timestamp in UTC after pre-launch QA, plus the corresponding
   agreed 90-day flight boundaries in the campaign record. Deployment and this
   live check remain separate from local test completion.

## Produce each report

Use the normal host's release console or RPC command from the deployed release
directory. Replace the example times with the recorded flight boundaries:

```sh
bin/elixir_drops rpc 'ElixirDrops.Sponsors.report(~U[2026-09-10 09:00:00Z], ~U[2026-10-10 09:00:00Z]) |> IO.inspect()'
```

Locally, the equivalent is:

```sh
mix run -e 'ElixirDrops.Sponsors.report(~U[2026-09-10 09:00:00Z], ~U[2026-10-10 09:00:00Z]) |> IO.inspect()'
```

The interval includes the start and excludes the end. Use contiguous 30-day
intervals, plus the whole 90-day interval for the final summary. Do not use the
example dates as an agreed schedule. The returned map always includes both
placements, impressions, clicks and percentage CTR.

Check period boundaries and counts, then copy the result into the sponsor report
with the measurement definition and limitations above. Retain the dated report
in the campaign's artifacts and link it from the campaign record. Sending the
report is a separate authorized action. Calendar reminders and manual campaign
removal remain operational tasks, not features of this tracker.

## Failure and resume

Event writes are best effort: database errors are logged and the reader can
still follow the redirect. A database outage can lose events; do not invent or
backfill counts. Record any affected interval and disclose it in the report.
Stored events survive app restarts and deployments, subject to database backups.
If a browser never connects its LiveView, no impression is recorded. Automated
traffic may evade the filter. Reports are delivery estimates, not audited human
reach or conversions.

After an interrupted deployment, confirm the migration and runtime QA setting,
then rerun the live checks before recording launch. A query-only report can be
repeated safely with the same timestamps. Completion means tested code, migrated
production database, verified QA exclusion and live counts, recorded start/end,
and a saved report after each agreed period.
