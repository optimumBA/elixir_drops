# Sponsor tracking and reporting

[Start here](../README.md)

The app owns AppSignal measurement. Campaign terms, approved creative and actual
flight dates are maintained privately by Optimum and are not part of this
repository.

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

Event inserts run synchronously. Each impression query has a one-second timeout; a duplicate replay can
require a second query to verify the stored row. Redirects make one click-write attempt with a 250ms query timeout and
`queue: false` (no waiting for a busy pool), then return the fixed 302 destination
even on failure. Scheduler/network time is outside this implementation budget;
250ms is not a response-time guarantee. A timed-out click may be lost or may
have committed before its reply was lost; it is never retried automatically.

For sponsor placements, the server acknowledges each placement only after storage
or an intentional QA/bot exclusion. The hook retries unacknowledged placements
up to three sends, after 1s and 3s delays; a missing reply times out after 5s.
Resize/reconnect cannot resend an acknowledged placement. Server-generated,
per-visit/per-placement/per-metric event UUIDs are reused for retries, and the
existing primary key prevents a lost reply from producing a second row. A
conflicting ID is acknowledged only if its sponsor, placement and kind match.
No migration or visitor identity is added.

Reports cannot reconstruct events that never reached storage after the bounded
retry attempts or a failed click write. Recorded clicks are not conversions.

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

Keep the email self-contained: provide the results and measurement limitations
without asking the sponsor to supply analytics, signups or other work to complete
our report. Do not infer conversions or ROI from redirect counts. This reporting
preference was specified by the owner on October 13, 2026.

Before querying production, resolve the current hosting workflow and verify the
host, deployed release and database. A historical host alias is not current
production evidence. If app RPC is unavailable, use the host's maintained
read-only release-eval route with only Repo started; do not run migrations or
start another Endpoint for a report. Infrastructure access and private campaign
dates remain with their maintained operational owners.

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

## Separate visible-impression estimate

New events have kind `visible_impression`. A browser qualifies a placement when
at least 50% of its area intersects the viewport continuously for 1000ms while
`document.visibilityState` is `visible`. Falling below the threshold, entering
a background tab or disconnecting resets an unfinished dwell. Qualification is
once per placement per LiveView visit, independent of served acknowledgment;
its delivery uses the same bounded retries and stable-ID protection. A qualified
event can finish delivery after scrolling away. Placements hidden with `display: none` never
qualify. This is an internal measurement rule, not audited viewability or a claim
of compliance with an advertising measurement standard. Browser reports remain
estimates and can be forged by automated clients.

Historical `report/2` keeps its existing map
shape and served CTR denominator. Query the new metric separately for matching
UTC intervals:

```elixir
ElixirDrops.Sponsors.visibility_report(from, to)
# %{placement => %{visible_impressions: count}}
```

Record the actual deployment/coverage start separately before using these
counts in a sponsor report. There is no historical visibility data to backfill;
zero rows before coverage do not mean zero exposure. Existing click counts remain
raw eligible redirect requests, not unique visitors or deduplicated people.

## Operational signals and coverage gaps

The existing AppSignal client receives these anonymous custom metrics directly:

- `sponsor_event` counter: outcome `attempted`, `persisted`, `skipped` or `failed`;
  tags are only sponsor, placement, kind, outcome and optional bounded skip reason.
- `sponsor_event_write_ms` distribution: write duration and outcome.
- `sponsor_redirect_ms` distribution: controller redirect duration and outcome.

The same measurements are emitted as `[:elixir_drops, :sponsors, :event | :write |
:redirect]` telemetry events for local consumers. No raw user agent, IP, user ID
or event UUID is included. Persistence failures, including returned validation
failures, are logged with their class. Intentional skips are counted separately
from attempted database writes. `persisted` counts successful attempts including
idempotent replays; use database rows for sponsor delivery totals, never the
operational counter as an impression total.

AppSignal must be enabled/configured in the deployment for remote collection.
Account retention, gaps before deployment, agent outages and dashboard/alert
configuration have not been verified by this local preparation. These signals
do not create a durable in-app availability ledger or recover past losses.
Check retained metrics and logs for each report interval; expired or absent logs
are not proof of uninterrupted measurement. No new service, alerting schedule or
retention promise is introduced.

### Regression checks

From the source root, run `node --test test/js/*.mjs` for acknowledgment/retry,
lost-reply, dwell/background and resize/reconnect regressions (Node's built-in
runner, no added dependency). Then run the normal project gate and focused tests:

```sh
mix test test/elixir_drops/integration/sponsor_reliability_test.exs test/elixir_drops_web/integration/sponsor_redirect_reliability_test.exs
FEATURE_TESTS=true PW_TIMEOUT=5000 mix test --include feature test/elixir_drops_web/features/sponsor_tracking_test.exs test/elixir_drops_web/features/sponsor_visibility_test.exs
```

The browser test checks actual below-fold geometry, scrolling, dwell, resize
and reconnect. Background dwell reset has deterministic JavaScript coverage;
a real background-tab check is currently blocked by Playwright's forced-focus
behavior on this host. Headed tab-switch/minimize probes, including disabling
focus emulation on a separate CDP session, still reported the document visible.
See [the upstream explanation](https://github.com/microsoft/playwright/issues/41873).
Do not describe those probes or fake-observer tests as a real background pass.
The timeout regression uses an isolated test-database trigger that sleeps two
seconds; the reader must still get the fixed redirect in under one second with
one attempted/failed write. Test setup is rolled back; never run that fixture
against production. `mix test` also builds assets, so serialize it with other
asset builders and use a separate test partition for concurrent test processes.
