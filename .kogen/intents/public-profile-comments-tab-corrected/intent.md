# Complete the public profile Comments feed

Slug: public-profile-comments-tab-corrected
Model: not applicable — the feed is a rendered, cursor-paged view over existing comment rows; no new persistent state
Acceptance:
- .kogen/intents/public-profile-comments-tab-corrected/acceptance.feature
- features/steps/public-profile-comments-tab-corrected__run.js
- features/steps/public-profile-comments-tab-corrected__driver/support.exs
- features/steps/public-profile-comments-tab-corrected__driver/feed_test.exs
- features/steps/public-profile-comments-tab-corrected__driver/interrupted_test.exs
- features/steps/public-profile-comments-tab-corrected__driver/bound_test.exs
- features/steps/public-profile-comments-tab-corrected__driver/presentation_test.exs
- features/steps/public-profile-comments-tab-corrected__driver/tabs_browser_test.exs
- features/steps/public-profile-comments-tab-corrected__driver/discussion_browser_test.exs

The public profile Comments tab shows a placeholder ("The comment activity list is not available yet.") although the contributor has comments. Replace it with the viewed contributor's public comments AND replies as a single-column activity feed, newest first, loading further batches of ten automatically on scroll, for guests and signed-in visitors. The existing profile header, navigation bar, tabs, search placement and styling stay as they are (the owner accepts the navigation bar; this is not a layout task). The feed shows a genuine empty state only for a contributor with no comments, a loading state, a retry state that keeps already loaded entries and never skips a batch or pretends the feed ended, and an exhausted state. Each entry shows its linked Drop title, a date, the formatted (real Markdown and code) body, for a reply the reply-to identity and a short excerpt of the parent comment, long-content expand/collapse, and a View in discussion link that opens that exact comment or reply even when it is older than the Drop page's initially loaded conversation. Both tabs keep their own loaded entries and position across tab switches and across a visit to a Drop and Back, including a batch interrupted by switching. Private My drops, author-scoped Drops search, comment create/edit/delete, authorization and public/private identity boundaries are unchanged. This supersedes the earlier profile intent's notice-only Comments tab (its `not available yet` expectation no longer holds); the Build updates any test of the repository's own that asserts the placeholder.

Observable contract used by the acceptance (chosen by the Shaper, see Decisions): inside the existing `#profile-comments` container the feed carries exactly one rendered attribute whose value is one of `idle`, `loading`, `retry`, `empty`, `exhausted`; continuation batches use the existing `load_more` event; in the retry state the container holds one retry button, the only `button` inside it without `aria-expanded`; each entry's own body text appears once in the markup (collapse is presentational); fixtures identify entries by unique body tokens, not by invented ids.

## Decisions
- The feed lists every stored comment and reply whose user is the viewed contributor, nothing else, identical for guests and signed-in visitors, ordered by timestamp descending with a unique tie-break so every entry appears exactly once across batches; the Comments total equals the feed's entries. (evidence: lib/elixir_drops/comments.ex; lib/elixir_drops/comments/comment.ex; lib/elixir_drops_web/live/profile_live/show.html.heex) (source: request)
- Availability follows the real model: a Drop is a stored row and hard-deleted Drops cascade away their comments, and a deleted parent cascades its replies; fixtures delete real Drops and parent comments and assert the surviving entries, with no invented draft, soft deletion or schema change. (evidence: priv/repo/migrations/20250703134839_create_comments.exs; lib/elixir_drops/comments.ex) (assumption: the Drop-delete cascade is as the request states; not re-probed in this shaping) (source: request)
- Batch size is ten entries as the delegated default; continuation batches after the first are fetched asynchronously like the Drops tab so a held request shows loading and a failed one shows retry with the same batch re-requested. (decision: D3, round 1) (evidence: lib/elixir_drops_web/live/profile_live/show.ex; lib/elixir_drops_web/live/drops_list_helper.ex) (assumption: ten per batch is the request's delegated default and may be revised later) (source: request)
- Database work per batch is bounded and does not grow with history size: opening the Comments tab and every continuation batch cost no more repo queries for a contributor with 100 entries than for one with 15, and a batch never costs one query per entry it adds; no per-item query and no full-history fetch. The acceptance takes the bound from the observed cost for 15 entries and states no fixed query number. (decision: D4, round 1) (source: request)
- An entry's date is an absolute calendar date including the year; a reply shows its parent author as the existing contributor attribution link plus a short excerpt of the parent that omits the end of a 1000-character parent; internal anchors (Drop title, parent author, View in discussion) have no target attribute and keep same-tab navigation. (decision: D5, round 1) (evidence: lib/elixir_drops_web/live/drop_components.ex; lib/elixir_drops_web/live/comment_components.ex) (assumption: absolute-date format and excerpt cut are chosen by the Shaper; the acceptance asserts only year, month and the omitted tail) (source: request)
- Long content expands and collapses through a `button` with `aria-expanded` (false collapsed, true expanded), operable from the keyboard with a visible focus indication; the maximum body length the model allows is 1000 characters. (decision: D6, round 1) (evidence: lib/elixir_drops/comments/comment.ex) (assumption: the aria-expanded button is the Shaper's accessible-control choice) (source: request)
- View in discussion opens the Drop page at the exact comment or reply and reveals it (replies container opened, element inside the viewport), including comments older than the first ten top-level comments the Drop page loads initially; the existing `show_comment` hook currently assumes the target is already in the DOM. (decision: D7, round 1) (evidence: lib/elixir_drops_web/live/drop_live/show.ex; assets/js/hooks/comment_form.js; lib/elixir_drops/comments.ex) (source: request)
- Both profile tabs keep their loaded entries (same entries in the same order, none lost or repeated) and the first visible entry when switching tabs and when returning with Back from a Drop; a batch interrupted by a tab switch ends with either its entries appended whole or the batch re-requestable, never skipped or duplicated, and continuing afterwards yields every entry exactly once. Equivalent stable restoration of position is accepted instead of pixel equality. The feed test asserts at LiveView level that patching to the Drops tab and back keeps the 20 loaded entries, and the interrupted test asserts the interrupted-batch outcome. (decision: D8, round 1) (evidence: lib/elixir_drops_web/live/profile_live/show.ex; assets/js/hooks/infinite_scroll.js) (source: request)
- Controls are deferred: the change spans the context, LiveView, template, JavaScript hooks and the Drop page, so correct and wrong overlays cannot be written honestly in the shaping budget; the Build writes the implementation and its own tests under test/. (decision: D9, round 1) (assumption: deferral of wrong-implementation controls is acceptable, as in the earlier profile intent) (source: request)
- The Comments tab renders the viewed contributor's stored comments and replies (all rows with their user_id) as a single-column, newest-first feed of 10 entries per batch, for guests and signed-in visitors alike, with a unique tie-break for equal timestamps; the placeholder is removed. (decision: D1, round 1) (evidence: lib/elixir_drops_web/live/profile_live/show.html.heex; lib/elixir_drops/comments/comment.ex; lib/elixir_drops/comments.ex) (assumption: Batch size 10 is the request's delegated default.) (source: request)
- Availability follows the real model: a Drop hard-delete cascades its comments and a deleted parent cascades its replies, so the feed and the Comments total count the same stored rows; fixtures use Repo.delete of real Drops and parent comments. (decision: D2, round 1) (evidence: priv/repo/migrations/20250703134839_create_comments.exs; lib/elixir_drops/comments.ex) (assumption: Drop to comments cascade is taken from the request statement and the existing profile intent; not re-probed.) (source: request)

## Source comparison
- Placeholder replaced by comments and replies feed, guests and signed-in, newest first, ten per batch, automatic scroll loading, empty/loading/retry/exhausted: scenario 1, request.
- Batch interrupted by switching tabs, no skip or duplicate: scenario 2, request.
- Query/work bound for two sizes: scenario 3, request.
- Entry presentation (title link, date, Markdown/code, reply context, expand/collapse, same-tab links): scenario 4, request.
- Tab and Back continuity, keyboard focus, desktop and phone entries instead of placeholder: scenario 5 (and tab-switch retention in scenario 1), request.
- View in discussion reaching an older reply and older comment: scenario 6, request.
- Navigation bar, tabs, search placement: unchanged by owner correction; View on GitHub new-tab link: untouched, already delivered separately.
- Draft/unpublished/soft-deleted rows: not in the model, not fixtured.
- Earlier profile intent's `not available yet` notice: superseded; its files are not edited here.

## Tests
- Feed contents, isolation, totals, batches, ties, states, tab-switch retention, deletion cascade, guest and signed-in parity: feed_test.exs (scenario)
- Batch interrupted by a tab switch is neither skipped nor duplicated: interrupted_test.exs (scenario)
- Bounded queries per batch for 15 and 100 entries: bound_test.exs (integration)
- Entry presentation, Markdown/code, reply context, links, date, expand control markup: presentation_test.exs (scenario)
- Tab switching, interrupted batch, Back from a Drop, keyboard focus, desktop and phone feed in a real browser: tabs_browser_test.exs (scenario)
- View in discussion reveals the exact older reply and comment, expand/collapse in a real browser: discussion_browser_test.exs (scenario)
- Build adds focused unit and LiveView tests under test/ for the new Comments context query and the profile feed, and updates tests asserting the placeholder: test/elixir_drops/comments_test.exs, test/elixir_drops_web/live (integration)
- My drops, search, comment create/edit/delete, authorization: existing tests (existing)

## Feasibility
- none
