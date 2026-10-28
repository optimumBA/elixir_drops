# Sponsor measurement contract

Executable owner: [sponsors.qnt](../quint/sponsors.qnt). The canonical report commands,
period selection, QA checks and definitions remain [docs/sponsor-tracking.md](../docs/sponsor-tracking.md).
Private bookings, prices, invoices, exclusivity and campaign expiry decisions belong
outside this public source specification; this baseline records only deployed app behavior.

**P01 — inventory (baseline).** Current first-party measurement supports `appsignal`
and two allowlisted placements: `drop-banner` and `drop-sidebar`. Destination URLs are
fixed approved AppSignal URLs tagged with the existing UTM campaign and placement.
A client cannot choose a redirect destination. Unknown/malformed placement values
are ignored for impressions and return 404 for redirects.

**P02 — impression eligibility (baseline).** Count a unit when its element renders
with positive width/height on the detail page, not as a viewability/dwell-time claim.
A hidden desktop sidebar does not count on a narrow viewport; showing it after resize
can count once. Reports must refer to the current Drop short ID. Client delivery is
suppressed while disconnected and retried after a delivery failure. The server
allowlists and deduplicates submitted placement names; the render-visibility check
is client-side, not anti-fraud protection against forged LiveView events.

**P03 — dedup scope (baseline).** Within a mounted view's current Drop, count each
placement once. Repeated events/resizes do not add it. Changing the Drop resets the
seen set; navigating A → B → A can count A again. Independent views can each count.
This is not unique visitors and not global idempotency. Server seen markers are
consumed even when event persistence fails; the same mounted view can consequently
lose an impression (G09). The model preserves that current failure behavior.

**P04 — exclusions (baseline).** Skip configured QA GitHub users and recognized
bot/automation user agents. User agent and QA identity are transient filter inputs;
unknown or absent user agent is eligible. HEAD and prefetch/prerender/preview redirect
requests do not count as clicks. A normal known-placement request still redirects
when excluded or when database tracking fails. Redirects have `private, no-store`.
A click is a redirect request, not unique visitors or confirmed destination engagement.

**P05 — privacy (baseline).** Persist only generated event ID, sponsor, placement,
kind and timestamp. No raw user agent, IP address, visitor/session/user/Drop identity
or profiling key is stored in a SponsorEvent. Structural fields in the model express
this limitation; they do not audit access logs, external analytics or telemetry.

**P06 — reports (baseline).** Count events in UTC half-open `[from, until)` ranges;
require `from < until`. Always return both known placements, with impression/click
counts including zeros. CTR is `clicks / impressions * 100`, rounded to two decimals,
and null when impressions are zero. The integer model uses hundredths of a percent
with a separate defined flag for null. It does not cap CTR at 100 or infer conversion
from clicks. QA/bot filtering and in-memory dedup are not proof of fraud resistance.

DB and delivery failures are explicitly exercised; real aggregate SQL, timezone
conversion, malformed-list filtering, user-agent regexes, HTTP HEAD/prefetch headers
and responsive rendered crops remain implementation/browser-test obligations.
