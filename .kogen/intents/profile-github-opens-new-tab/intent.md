# Open the public profile GitHub link in a new tab

Slug: profile-github-opens-new-tab
Model: not applicable — the change adds two static attributes to one existing anchor; no state or interacting rules
Acceptance:
- .kogen/intents/profile-github-opens-new-tab/acceptance.feature
- features/steps/profile-github-opens-new-tab__run.js
- features/steps/profile-github-opens-new-tab__driver/rendered_test.exs
- features/steps/profile-github-opens-new-tab__driver/browser_test.exs
- features/steps/profile-github-opens-new-tab__driver/new_tab.cjs
- features/steps/profile-github-opens-new-tab__driver/internal_links_test.exs

The public profile's View on GitHub anchor (https://github.com/ followed by the viewed contributor's username) gets native new-tab behavior: `target="_blank"` with `rel` containing both `noopener` and `noreferrer`. The href stays the viewed contributor's GitHub URL (never the signed-in viewer's), the visible label stays "View on GitHub", and the anchor carries no click handler or script attribute (no `window.open`). The original profile tab stays at its URL and content.

Only `lib/elixir_drops_web/live/profile_live/show.html.heex` may change in production code, plus new or extended test files under the existing test directories. Every other template, the layout, the navigation bar/header/search, CSS, README and documentation are out of scope and unchanged. Internal Drops/Comments/profile/discussion links and navigation bar links, the GitHub authentication flow and account actions are unchanged: they keep their href and have no target. Nothing is removed.

Acceptance runs three new ExUnit files under `features/steps/profile-github-opens-new-tab__driver/`, one per scenario. The browser file (`mix test --include feature` with `FEATURE_TESTS=true`) starts the real test server, then runs `new_tab.cjs` with the repository's Playwright (`assets/node_modules/playwright`) and Chromium; the script answers every request to the github.com origin from a local static fixture page and aborts any other non-local request, so no outside network, GitHub login, post or account change happens. The files are acceptance machinery and are not rewritten by the Build.

## Decisions
- The fix is exactly `target="_blank"` and `rel="noopener noreferrer"` on the existing anchor in the profile template; the href expression and label are untouched, and no JavaScript opening is used. (evidence: lib/elixir_drops_web/live/profile_live/show.html.heex) (source: request)
- The browser scenario drives Playwright from a Node helper using the repository's Playwright package, with context-level request routing and page events, against the running test server. The ExUnit test runs shared-sandbox (not async) so the externally launched browser sees fixture data. (evidence: assets/package.json; config/test.exs; test/support/data_case.ex) (assumption: the Elixir PhoenixTest.Playwright wrapper offers no request-routing or multi-page API, which was observed only by searching untracked dependency sources; Chromium for the repository's Playwright version is installed by the project's assets setup in the acceptance environment; the driver was not run in shaping) (source: request)
- Exactly one new browsing context means the Playwright context holds the original page plus one new page after activation, with the new page at the contributor's GitHub URL and the original page still at its profile URL with its profile header text unchanged. (evidence: lib/elixir_drops_web/live/profile_live/show.html.heex) (source: request)
- Controls are deferred: the browser path cannot be honestly overlaid and verified within the shaping budget; the rendered-HTML and browser drivers fail on the unchanged tree at the new-tab assertions, while scenario 3 passes on the unchanged tree. (assumption: deferral of wrong-implementation controls is acceptable) (source: request)
- The internal-navigation scenario asserts, on the rendered profile (guest and signed-in), that every site-relative link to a Drops, Comments, profile, discussion or home page has no target attribute, and that the Drops and Comments tab hrefs are `/u/<id>/drops` and `/u/<id>/comments`, the home link `/` and a Drop card link `/d/<short_id>` are present, and that no such link points at github.com. Site-relative links to a Markdown file (`.md`) and to `/go/` sponsor redirects are not links to a Drops, Comments, profile or discussion page, so the scenario does not select them; the Drop card menu's Markdown link already carries a target on the unchanged tree, so selecting it would make scenario 3 fail on the unchanged tree. (evidence: lib/elixir_drops_web/router.ex; lib/elixir_drops_web/live/drop_components.ex; lib/elixir_drops_web/live/drops_list_helper.ex) (revises: D7 because the first version asserted no target on every non-GitHub anchor and was red on the unchanged tree) (source: request)
- Add target=_blank and rel="noopener noreferrer" to the existing View on GitHub anchor only; no script opening. (decision: D1, round 1) (constraint: only show.html.heex changes in production code) (evidence: lib/elixir_drops_web/live/profile_live/show.html.heex) (assumption: none) (source: request)
- Browser scenario uses a Node Playwright helper with context routing for github.com against the running test server in shared-sandbox mode. (decision: D2, round 1) (evidence: assets/package.json; config/test.exs; test/support/data_case.ex) (assumption: Chromium installation and driver were not run in shaping; the driver was written without execution.) (source: request)
- Controls deferred because the browser path could not be overlaid and verified within budget. (decision: D3, round 1) (assumption: No wrong-implementation controls were run.) (source: request)
- The fix is exactly target=_blank and rel="noopener noreferrer" on the existing anchor in the profile template; href and label untouched, no JavaScript opening. (decision: D4, round 1) (constraint: only show.html.heex changes in production code) (evidence: lib/elixir_drops_web/live/profile_live/show.html.heex) (assumption: none) (source: request)
- The browser scenario drives Playwright from a Node helper using the repository's Playwright package with context routing, against the running test server in shared-sandbox mode. (decision: D5, round 1) (evidence: assets/package.json; config/test.exs; test/support/data_case.ex) (assumption: Wrapper lacks routing API (seen only in untracked deps); Chromium install and driver not run in shaping.) (source: request)
- Exactly one new browsing context means original page plus one new page at the GitHub URL, original page URL and header text unchanged. (decision: D6, round 1) (evidence: lib/elixir_drops_web/live/profile_live/show.html.heex) (assumption: none) (source: request)
- Controls are deferred because the browser path could not be overlaid and verified within budget. (decision: D8, round 1) (assumption: No wrong-implementation controls were run.) (source: request)
- The internal-navigation scenario asserts no target on every site-relative navigation link (excluding the pre-existing View as Markdown .md menu link and /go/ sponsor redirects), pinned tab, home and Drop card hrefs, and no internal link to github.com. (decision: D9, round 1) (evidence: lib/elixir_drops_web/router.ex; lib/elixir_drops_web/live/drop_components.ex; lib/elixir_drops_web/live/drops_list_helper.ex) (assumption: Other pre-existing non-navigation anchors with targets, if any, were not enumerated; the test was not run in shaping.) (revises: D7 because the first version asserted no target on every non-GitHub anchor, but the unchanged Drop card menu already renders a target=_blank Markdown link, which no correct implementation may change) (source: request)

## Source comparison
- Scenario 1 rendered attributes, guest and signed-in different person: rendered_test.exs (addressed, source: request).
- Scenario 2 browser activation opens exactly one new context, original tab unchanged, no outside network: browser_test.exs with new_tab.cjs (addressed, source: request).
- Scenario 3 internal navigation unchanged, passes on unchanged tree: internal_links_test.exs (addressed; selects links to Drops, Comments, profile, discussion and home pages, source: request).
- Omitted: none. Conflicting: none. Navigation bar, header, search, Comments feed, CSS and docs are not touched (source: request).

## Tests
- GitHub anchor target, rel, href, label and no script handler for guest and signed-in viewer: rendered_test.exs (scenario)
- Browser activation opens one new context at the contributor's GitHub URL and leaves the original tab unchanged: browser_test.exs (scenario)
- Internal and navigation links keep href and have no target: internal_links_test.exs (regression)
- none: the operation renders a single profile with a fixed small fixture and has no operation over a collection of unknown size

## Feasibility
- none
