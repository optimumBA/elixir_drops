# Add archive link to the homepage body

Slug: crawlable-archive-entry-20261121
Model: not applicable — the change is one static link in a rendered template with no state or interacting rules
Acceptance:
- .kogen/intents/crawlable-archive-entry-20261121/acceptance.feature
- features/steps/crawlable-archive-entry-20261121__run.js
- features/steps/crawlable-archive-entry-20261121__driver/homepage_link_test.exs
- features/steps/crawlable-archive-entry-20261121__driver/archive_reach_test.exs

The public homepage (`/`) gets one visible, ordinary HTML link to the existing `/archive`, rendered in the page body just above the Latest Drops feed, so that the archive and every article it lists are reachable from the homepage's initial HTML without JavaScript. The link text is "Browse all Drops". The header (navbar) gets no archive link; the owner requires the header to stay as it is. Infinite scroll, the archive route and page, all existing article URLs, the header design, private boundaries and all other current behavior are unchanged. Nothing is removed or replaced.

## Decisions
- The link is a plain `<a href="/archive">` (Phoenix `.link` with `href`, not `navigate`, `patch` or a click handler) with the text "Browse all Drops", rendered by the homepage template in the dead (initial) render and again after connect, for signed-out and signed-in visitors. (evidence: lib/elixir_drops_web/live/drop_live/index.html.heex; lib/elixir_drops_web/controllers/archive_html/index.html.heex) (source: request)
- The link sits inside the `#main-page-body` section, outside the `header`/`nav` navbar, immediately before the feed container (`id="drops"`), because infinite scroll means anything after the feed is not reachable; it is right-aligned with the feed's horizontal padding. (evidence: lib/elixir_drops_web/live/drop_live/index.html.heex; lib/elixir_drops_web/live/drops_list_helper.ex) (source: request)
- Existing styling is reused: the archive page's own secondary link classes `text-sm font-medium text-[#656565] hover:text-[#5947F1]`; no new CSS, component or setting. (evidence: lib/elixir_drops_web/controllers/archive_html/index.html.heex) (source: request)
- The header must have no archive link, hidden or visible; the navbar component is not edited. (evidence: lib/elixir_drops_web/live/drop_components.ex; docs/seo.md) (source: request)
- The homepage contains exactly one link whose path is `/archive`, and it is not hidden (no `hidden`, `sr-only`, `invisible` class token at any breakpoint, no `hidden` or `aria-hidden` attribute on it or an ancestor), so it is visible on desktop and phone. (source: request)
- docs/seo.md's Discovery paragraph is updated to say the homepage body (not the header) links to the archive; the header statement stays. (evidence: docs/seo.md) (source: request)
- Rendered desktop and phone review of the homepage is done by the Build/QA through the existing background browser route only (existing `test/elixir_drops_web/features/ui_visual_test.exs` homepage viewport checks plus a screenshot of `/` at desktop and phone widths); it is not part of the Gherkin acceptance because it needs a browser. The Build reports exactly which commands it ran and their results as the native build and QA readback. (evidence: test/elixir_drops_web/features/ui_visual_test.exs) (assumption: the existing background browser route is the allowed route; no new capture tool is added) (source: request)
- Acceptance fixtures use 20 Drops, five more than the homepage batch size of 15, so the oldest Drop is not in the homepage's first batch and is reachable only through the archive link. (evidence: lib/elixir_drops_web/live/drop_live/index.ex) (source: request)
- Add one plain Phoenix .link href to /archive with text 'Browse all Drops' in the homepage body above the feed; header untouched (decision: D1, round 1) (evidence: lib/elixir_drops_web/live/drop_live/index.html.heex; lib/elixir_drops_web/live/drop_components.ex; lib/elixir_drops_web/controllers/archive_html/index.html.heex; docs/seo.md) (assumption: Rendered desktop/phone appearance is not asserted by acceptance; the existing browser route is left to Build QA. The ExUnit drivers and controls were not run in this session (read-only); only git apply --check of the correct patch was run.) (source: request)

## Source comparison
- Addressed: one visible ordinary body link from `/` to `/archive` with concise copy "Browse all Drops" (request; acceptance scenario 1).
- Addressed: no archive link in the header (request; scenario 1 asserts none in `header`/`nav`, exactly one `/archive` anchor in the page).
- Addressed: representative older archive article reachable without JavaScript — the archive page reached by following the homepage link lists the oldest Drop's `/d/<short_id>` link and that URL still serves the article (scenario 2).
- Addressed: infinite scroll marker, archive route and article URLs preserved (scenario 2).
- Addressed elsewhere: existing app gates (`make ci`) are run by the Build; rendered desktop/phone review per Decisions.
- Context only, not a requirement: live sitemap numbers (204 URLs, 16 reachable, 202 archive links) motivate the change and are not asserted.

## Tests
- Homepage initial HTML (signed out and signed in, plain GET and connected LiveView) has exactly one visible ordinary "Browse all Drops" link to `/archive`, in `#main-page-body`, outside header/nav, before the feed: `homepage_link_test.exs` driven by acceptance scenario 1 (scenario)
- Following the homepage link reaches the archive, which links the oldest Drop (absent from the homepage first batch), whose article URL still serves; infinite-scroll marker still present: `archive_reach_test.exs` driven by acceptance scenario 2 (scenario)
- Archive page, article pages, sitemap, 404 page and the rest of the app are unchanged: existing suite (`mix test`, `make ci`) (existing)

## Feasibility
- none
