# Add public contributor profile with Drops tab

Slug: public-profile-page-and-drops-tab
Model: not applicable — page, tabs and feed states are rendered views over existing rows; no new persistent state or multi-step rules beyond the five feed state values asserted by the acceptance
Acceptance:
- .kogen/intents/public-profile-page-and-drops-tab/acceptance.feature
- features/steps/public-profile-page-and-drops-tab__run.js
- features/steps/public-profile-page-and-drops-tab__driver/profile_page_test.exs
- features/steps/public-profile-page-and-drops-tab__driver/drops_tab_test.exs

Contributors get a public profile page, reachable without sign-in, that shows the existing GitHub identity (name, avatar, username, GitHub link) and two totals (Drops and Comments), with two separate tab links, Drops and Comments. The Drops tab reuses the My drops feed components, screenshot cards, masonry layout and the `load_more` scroll event, scoped to the profile's author, with author-scoped search and viewport-aware automatic infinite scroll and no Previous or Next control. The Comments tab, in this request, shows the header, the Comments total and one short notice that the comment activity list is not available yet (the visible text contains the words `not available yet`), and lists no comments (the next request replaces the notice with the feed). The account menu gains View public profile, linking to the viewer's own profile; My drops stays the private author page and gains no Comments. Out of scope: bio or website editing, followers or reputation, sponsor changes, schema changes, new authorization rules.

The repository has no draft or unpublished Drop state and no soft deletion: a Drop is either a stored row, which is published and visible to every viewer, or hard-deleted, which cascades its comments away. So Drops total = the author's stored Drops, Comments total = the contributor's stored comments and replies (rows whose Drop was deleted no longer exist and are not counted), identical for every viewer. The acceptance cannot create a draft; it asserts no private data (email, session token, search history, draft or bookmark text) appears.

Acceptance runs two ExUnit files (one per scenario) under `features/steps/public-profile-page-and-drops-tab__driver/` with `mix test --trace <file>`; each file builds its fixture inside one test and finds links by visible text and the account-menu href, so the profile route itself is the Build's choice. The files are acceptance machinery and are not moved or rewritten by the Build. Every wait in a check has a limit of at most 10 seconds (the files express it as 10_000 milliseconds); a held or failed batch request is held or failed by the test itself, not by real waiting.

## Decisions
- The profile page is a public LiveView in the default live session (no sign-in), loading its user from the route and rendering the existing not-found page (HTTP 404, `Page not found`) when the user does not exist, with no header or totals. (decision: D1, round 1) (evidence: lib/elixir_drops_web/router.ex; lib/elixir_drops_web/controllers/error_html/404.html.heex) (source: request)
- The Drops tab loads batches asynchronously (`start_async`) through the existing `load_more` event and the My drops `batch_size` (15) so a batch can be held and failed by a test; a failed batch yields the retry state, never an end-of-timeline. (decision: D2, round 1) (evidence: lib/elixir_drops_web/live/live_helpers.ex; lib/elixir_drops_web/live/drops_list_helper.ex; lib/elixir_drops_web/live/user_drop_live/index.ex) (assumption: asynchronous loading is needed so loading is observable; the request requires a held request to show loading) (source: request)
- The feed container renders its state as one attribute (name chosen by the Build) whose value is exactly one of idle, loading, retry, empty or exhausted; the acceptance discovers it as the one rendered attribute whose value is one of these words. idle while more batches may exist, exhausted once a batch returns fewer than the batch size, empty when no Drop matches. Retry also renders a button with visible text `Retry` that reloads the same failed batch with no entry skipped or repeated. The Comments tab renders no such attribute. (decision: D3, round 1) (evidence: lib/elixir_drops_web/live/drops_list_helper.ex) (source: request)
- Totals are visible text: an element whose whole text is the integer with the label, either `<n> Drops`/`<n> Comments` or `Drops <n>`/`Comments <n>` (singular `Drop`/`Comment` allowed); tab links have visible text `Drops` and `Comments` (optionally followed by the count) and open directly; the default tab is Drops, or Comments when the contributor has no Drops. (decision: D4, round 1) (assumption: the visible label-and-number form is chosen by the Shaper) (source: request)
- Search on the Drops tab uses the `q` query parameter like My drops and filters by the profile's author only. (decision: D5, round 1) (evidence: lib/elixir_drops_web/live/user_drop_live/index.ex; lib/elixir_drops/drops.ex) (source: request)
- The account menu in `slide_menu` gains a link with text `View public profile` to the signed-in viewer's own profile; My drops stays. (decision: D6, round 1) (evidence: lib/elixir_drops_web/live/drop_components.ex) (source: request)
- Controls are deferred: the change spans several large files and overlays could not be verified in the shaping budget; both ExUnit files fail on current main. (decision: D7, round 1) (assumption: deferral of wrong-implementation controls is acceptable; the files were not run to completion in shaping and the table-rename failure injection and telemetry hold were not run) (source: request)

## Source comparison
- Public access, identity, totals, privacy, tabs, default, account menu, unavailable user: scenario 1 (source: request).
- Drops tab, four feed states, search scope, infinite scroll, no Previous/Next: scenario 2 (source: request).
- Drafts and per-viewer availability: not represented in the repository, therefore not created in fixtures (evidence: lib/elixir_drops/drops/drop.ex).
- Comments feed, keyboard, scroll-position checks, discussion links: second request, omitted.
- My drops, create/edit/search/delete, authorization, schemas: unchanged, protected by existing tests.

## Tests
- Public profile access, identity, privacy, totals, tabs, default, menu link, not found: profile_page_test.exs (scenario)
- Drops tab feed states, scoped search, scroll to exhaustion, no Previous/Next: drops_tab_test.exs (scenario)
- My drops and existing pages: existing tests (existing)
- none: the Drops feed loads fixed-size batches on scroll (never the whole collection at once), so the work per request is bounded by the batch size and cannot grow with the record count; the acceptance scrolls three batches instead

## Feasibility
- none
