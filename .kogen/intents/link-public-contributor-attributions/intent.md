# Link public contributor attributions

Slug: link-public-contributor-attributions
Model: not applicable — the change turns existing identity markup into links over existing rows; no new persistent state or multi-step rules
Acceptance:
- .kogen/intents/link-public-contributor-attributions/acceptance.feature
- features/steps/link-public-contributor-attributions__run.js
- features/steps/link-public-contributor-attributions__driver/viewers_test.exs
- features/steps/link-public-contributor-attributions__driver/discussion_test.exs
- features/steps/link-public-contributor-attributions__driver/browser_test.exs
- features/steps/link-public-contributor-attributions__driver/unresolvable_test.exs

Corrective slice of the existing public profile outcome. The public profile route `/u/:user_id` already exists and is reused unchanged. Public contributor avatars and visible author names/usernames become genuine semantic anchors to that exact contributor's profile on Drop cards (home, search, My drops, public-profile feed), on Drop detail, and on comments including replies. A small shared attribution component is used where current conventions permit. Avatar and name are one coherent accessible target, or separate targets with meaningful names without redundant keyboard noise. Pointer, hover and focus affordance match the current brand.

Author links are independent of the card's Drop link and options actions: no nested anchors and no parent click handling that navigates to the Drop instead of the author; Command/Ctrl-click, middle-click, context menu and keyboard stay native. Guests need no authentication. A missing, deleted or unresolvable author keeps a safe unlinked attribution with no empty, placeholder or fabricated link. Email, account secrets and private data are never rendered. The href always names the viewed contributor, never the visitor. Cards that are not contributor Drops (sponsor, promoted) are unchanged, get no author link and are not asserted against.

Unchanged and protected by existing tests: the account menu's own View public profile link, Drop card title/body destination, options menus, author action permissions, comment/reply actions, the profile route and page, router, schema, README and design-system files. Nothing is removed.

Acceptance runs four new ExUnit files under `features/steps/link-public-contributor-attributions__driver/` (one per scenario; three rendered-page files and one browser file with `FEATURE_TESTS=true mix test --trace --include feature`), each building a fixture of at most three authors, one Drop with one comment and one reply. Cards are selected by their fixture title; the author links of a card are all anchors in it whose path is the profile route, and checks take the first and last such anchor rather than assuming one. The files are acceptance machinery and are not rewritten by the Build.

## Decisions
- Author links target exactly the existing profile route path `/u/<user id>` of the displayed author, and the acceptance compares the path (not the query) of the first and last matching anchor of each selected card. (decision: D1, round 1) (evidence: lib/elixir_drops_web/router.ex; lib/elixir_drops_web/live/drop_components.ex; lib/elixir_drops_web/live/comment_components.ex) (source: request)
- Rendered-page acceptance covers home (guest and signed-in third user) and Drop detail; search is not separately rendered because it shares `drop_card`; the browser run covers the card, and My drops and profile feed share the same component. (decision: D2, round 1) (evidence: lib/elixir_drops_web/live/drop_components.ex) (assumption: sharing of drop_card across home, search, My drops and profile feed is taken from the request and the current component; those other pages are not rendered by acceptance) (source: request)
- The unresolvable author is acceptance-modelled by rendering the shared components directly with a Drop or comment whose user is missing (nil) or has no id, because the schema cannot store a comment without a user and deleting a user cascades. The correct build must render these without crashing and without any profile link. (decision: D3, round 1) (evidence: priv/repo/migrations/20250703134839_create_comments.exs; priv/repo/migrations/20240719103543_create_drops.exs; lib/elixir_drops_web/live/comment_components.ex) (assumption: direct component rendering stands for a deleted or unresolvable author) (source: request)
- Browser interactions are real Playwright keyboard, modifier-click and middle-click clicks. The modifier is the platform's open-in-new-tab modifier, chosen in the page from `navigator.platform`: Command (`Meta`) on macOS, Control elsewhere. Chromium on macOS turns Control+left-click into a context-menu gesture and never dispatches `click` for any anchor, so a Control-click is not a valid probe there (observed by the Build: Control gave mousedown, contextmenu, mouseup only; Meta gave mousedown, mouseup, click; middle gave mousedown, mouseup, auxclick; none default-prevented and the path stayed `/`). Opening a new tab is evidenced by the page staying on its URL and the observed click or auxclick not being default-prevented, since the existing test tooling drives one page. The scenario's Control-click wording denotes this platform modifier-click. (decision: D4, round 2) (evidence: test/elixir_drops_web/features/accessible_controls_test.exs; test/support/feature_helpers.ex; features/steps/link-public-contributor-attributions__driver/browser_test.exs) (assumption: not-default-prevented plus unchanged URL is accepted evidence of new-tab behavior) (source: request)
- Controls are deferred: the change spans two large component files and a new browser path; overlays for one correct and several wrong builds could not be verified in the shaping budget. (decision: D5, round 1) (assumption: deferral of wrong-implementation controls is acceptable; the driver files were not run in shaping) (source: request)

## Source comparison
- Scenario 1 (card and detail links, viewers): viewers_test.exs (addressed, unchanged) (source: request).
- Scenario 2 (comment and reply): discussion_test.exs (addressed, unchanged) (source: request).
- Scenario 3 (browser, three widths, no nested anchors): browser_test.exs (addressed; corrected in round 2). The Control-click step asserted a `click` event, which Chromium on macOS never dispatches for Control+left-click (context-menu gesture). It is replaced by a platform modifier-click (Meta on macOS, Control elsewhere) with the same assertions: path unchanged, event observed, not default-prevented, no options menu opened. Keyboard, middle-click, nesting, focus indicator, cursor and plain-click checks at 320, 390 and 1280 are unchanged. The scenario sentence in acceptance.feature and run.js keep their "Control-click" wording and are not edited; D4 states it denotes the platform modifier-click (superseded wording, same intent: Command/Ctrl-click natively opens a new tab) (source: request; Build report).
- Scenario 4 (unresolvable author, privacy): unresolvable_test.exs (addressed, unchanged) (source: request).
- Kept behavior, sponsor cards, account menu link, routes, schema, parked queues: protected by existing tests, not asserted (source: request).
- Omitted: none. Conflicting: none beyond the Control-click point above. The correction required no implementation or other test change; the Build's component edits are not part of this contract.

## Tests
- Drop card and detail author links per viewer: viewers_test.exs (scenario)
- Comment and reply author links: discussion_test.exs (scenario)
- Browser keyboard, modifier/middle click, nesting, focus and cursor at 320, 390, 1280: browser_test.exs (scenario)
- Unresolvable author unlinked and privacy: unresolvable_test.exs (scenario)
- Kept behavior of cards, menus and comment actions: existing tests (existing)
- none: the operation renders a fixed small fixture and links existing rows one per rendered attribution, with no bulk operation over a collection of unknown size

## Feasibility
- none
