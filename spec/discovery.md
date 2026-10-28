# Discovery, search and browser interaction

Executable owner: [discovery.qnt](../quint/discovery.qnt).

**B01 — collections (baseline).** The homepage includes completed/skipped screenshot
states; pending/failed states are excluded. The profile is always scoped to its
signed-in author and has no homepage status filter. A detail page and the full
archive include every saved Drop. Latest queries order by creation time descending;
the full archive additionally uses ID descending. Search order is relevance descending.
Deterministic tie handling across pages is a refinement (G03).

**B02 — updates (baseline).** A new Drop without code, or a completed screenshot from
a new Drop, raises the homepage's “New Drops” indicator. It does not move the existing
cards automatically. Refresh resets pagination and reloads the current collection.
Profiles refresh on their author's creation event and ignore other authors' image
updates. Reconnection reestablishes subscriptions. The finite discovery model uses
publication readiness events and view snapshots; exact PubSub/socket subscriptions
remain LiveView test obligations.

**B03 — pagination and layout (baseline intent; G03/G08 refinements).** Request one
page at a time while connected; suppress duplicate scroll/intersection requests until
completion. Stop after a short/empty page; a full final page may require one extra
empty request. Preserve the collection/filter when loading more, without duplicates
or omitted tied items. A response from a superseded search/view must not contaminate
its replacement. The model uses a view epoch and a two-card page to stress ties and
stale responses; these are abstractions, not mandated database/UI fields.

Viewport columns are 1 through width 480, 2 through 768, 3 through 1400, 4 through
1800, otherwise 5. Visible rows are `max(floor((height - 200) / 350), 1)`. Page size
is `clamp(max(columns * rows, columns * 2) + columns, 6, 40)`. Model tests check these
boundaries; actual cursor queries and resizing remain implementation tests.

In managed Masonry layout, appended cards stay hidden until positioned. Clearing or
destroying layout releases pending visibility; reconnect rebuilds it. Slow images
must not permanently block scrolling. The model tracks pending/positioned membership,
not pixel geometry, `requestAnimationFrame`, image timers or accessibility rendering.

## Search

**S01 — interpretation (baseline).** Trim search submission; blank input clears the
filter and does not count as a search. Current full-text semantics are PostgreSQL
English `websearch_to_tsquery`: phrases/operators and descending `ts_rank`. Preserve
that user-visible contract when changing the engine, or authorize a changed contract.
The model treats matching Drop IDs and ranks as supplied inputs; it does not implement
English stemming, phrase parsing or floating-point ranking. Profile search remains
owner-scoped; navbar search navigates to the homepage.

**S02 — tracking (baseline).** Record a nonblank submitted search, independently of
rendering results. Signed-in users get private history and global popularity;
anonymous users affect popularity only. Popularity normalizes trim/lowercase and uses
an atomic increment per normalized query. History preserves the submitted query and
has no unique-row constraint. Failures in asynchronous tracking do not prevent search
navigation. History `results_count` is currently capped at 100 returned results and
is not a promise of total matching corpus size. Model query IDs represent normalized
values; exact spelling/case behavior requires source tests.

**S03 — history and suggestions (baseline intent).** Return the most recent occurrence
of each history query, at most 100, private to its user. Deleting a history entry
removes every occurrence of that query for that user only. Suggestions offer at most
two matching recent history queries followed by at most three popular queries,
excluding overlap; anonymous users see up to five popular queries. Missing inventory
does not require filling the history quota with additional popular entries. Popular
queries rank by count descending; tie order is unspecified in source. The model uses
query ID as a deterministic tie representative and deduplicates history prefixes;
current prefix-history duplication is G06.

Focus can show suggestions without a prefix. Typing is debounced by approximately
100 ms; inputs shorter than two characters clear/avoid typed suggestions on the main
search path. Only visible/active inputs should send typing events. Blur allows a
suggestion click; Escape closes the mobile overlay. The profile/navbar paths are not
fully consistent today (G06); the abstract `suggest` action describes valid context
results, not an assertion that every browser path calls it identically.

## Other browser behavior

**U01 — welcome message (baseline).** Absent dismissal cookie means show the banner.
Dismissal writes `show_welcome_message=false` for one year and is read on the next
server render, preventing a reconnect/remount flash. The model covers persistence
within that lifetime; expiry/browser deletion is an external input, not modeled time.

**U02 — editing and clipboard (baseline intent).** Textareas fit their content and
resize on input/updates. Comment submit is disabled outside 1–1000 characters, with
server validation still authoritative. Cancel clears the draft and releases focus.
Code-copy controls copy code text without HTML markup; Drop-link controls copy the
canonical link and stop card navigation. Feedback is transient. Clipboard permission
failure and repeated hook installation are browser test obligations, not inferred
success from a click or model state. Mobile create controls hide after scrolling
past 300 px; scroll-to-top is a local interaction. These hooks do not persist data.

**U03 — image progress (baseline).** Display pending progress and completed/failed
states. Cosmetic animation is not backend completion: the browser may animate toward
60%, but only confirmed worker completion reaches final availability. A client
`progress_animation_complete` event is UI state, never authority to publish screenshot
URLs or change persisted screenshot status. Different jobs/retries can reset progress;
the delivery model's monotonic progress applies only within one attempt.
